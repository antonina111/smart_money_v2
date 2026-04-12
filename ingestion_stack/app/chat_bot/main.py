import os
import re
from typing import Any, Dict, List

import requests
from google.cloud import bigquery
from google import genai
from google.genai import types
from google.cloud import secretmanager
import functions_framework

# -------------------------
# CONFIG
# -------------------------
PROJECT_ID = os.environ.get("GCP_PROJECT", "mineral-brand-231612")
ALLOWED_VIEW = f"{PROJECT_ID}.curated.vw_market_klines_clean"
MAX_ROWS = 200

def get_secret(secret_id: str, project_id: str) -> str:
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
    response = client.access_secret_version(name=name)
    return response.payload.data.decode("UTF-8")


TELEGRAM_TOKEN = get_secret(
    secret_id="TELEGRAM_API_SECRET",
    project_id=PROJECT_ID,
)

TELEGRAM_API = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}"

LOCATION = os.environ.get("VERTEX_LOCATION", "europe-west1")
MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash")


# -------------------------
# CLIENTS (init once)
# -------------------------
bq = bigquery.Client(project=PROJECT_ID)

client = genai.Client(
    vertexai=True,
    project=PROJECT_ID,
    location=LOCATION,
)

tool = types.Tool(
    function_declarations=[
        types.FunctionDeclaration(
            name="execute_sql_query",
            description="Run a read-only BigQuery SELECT query on market data.",
            parameters=types.Schema(
                type="OBJECT",
                properties={"sql_query": types.Schema(type="STRING")},
                required=["sql_query"],
            ),
        )
    ]
)

SYSTEM_PROMPT = f"""
You are a data chatbot.
To answer questions, you MUST call execute_sql_query.

Rules:
- Only use this view: `{ALLOWED_VIEW}`
- Always use SELECT or WITH...SELECT
- Always use backticks around the view name
- Keep results small
Schema:
symbol, timeframe, kline_start_ts, kline_start_time, open_price, high_price, low_price,
close_price, number_of_trades, is_kline_closed
"""

# -------------------------
# SAFE SQL EXECUTOR
# -------------------------
BLOCKLIST = [
    r"\bDELETE\b", r"\bUPDATE\b", r"\bINSERT\b", r"\bMERGE\b",
    r"\bDROP\b", r"\bALTER\b", r"\bCREATE\b", r"\bEXPORT\b",
    r"\bCALL\b", r"\bGRANT\b", r"\bREVOKE\b",
]

def _normalize_sql(sql: str) -> str:
    return re.sub(r"\s+", " ", sql.strip())

def _is_read_only(sql: str) -> bool:
    up = sql.strip().upper()
    return up.startswith("SELECT") or up.startswith("WITH")

def _contains_blocked(sql: str) -> bool:
    up = sql.upper()
    if ";" in sql:
        return True
    return any(re.search(p, up) for p in BLOCKLIST)

def _extract_backticked_refs(sql: str) -> List[str]:
    return re.findall(r"`([^`]+)`", sql)

def _allowed_only(sql: str) -> bool:
    refs = _extract_backticked_refs(sql)
    if not refs:
        return False
    return all(r == ALLOWED_VIEW for r in refs)

def _ensure_limit(sql: str) -> str:
    up = sql.upper()
    if " LIMIT " not in up:
        return f"{sql} LIMIT {MAX_ROWS}"
    m = re.search(r"\bLIMIT\s+(\d+)\b", up)
    if m and int(m.group(1)) > MAX_ROWS:
        return re.sub(r"\bLIMIT\s+\d+\b", f"LIMIT {MAX_ROWS}", sql, count=1, flags=re.IGNORECASE)
    return sql

def execute_sql_query(sql_query: str) -> Dict[str, Any]:
    sql = _normalize_sql(sql_query)

    if not _is_read_only(sql):
        return {"error": "Only SELECT/CTE queries are allowed."}
    if _contains_blocked(sql):
        return {"error": "Forbidden SQL tokens found."}
    if not _allowed_only(sql):
        return {"error": f"Query must reference only `{ALLOWED_VIEW}` using backticks."}

    sql = _ensure_limit(sql)

    job = bq.query(sql)
    it = job.result()
    rows = list(it)
    out_rows = [dict(r.items()) for r in rows]

    schema_fields = getattr(it, "schema", None) or getattr(job, "schema", None)
    if schema_fields:
        schema = [{"name": f.name, "type": f.field_type} for f in schema_fields]
    else:
        schema = [{"name": k, "type": "UNKNOWN"} for k in out_rows[0].keys()] if out_rows else []

    return {"executed_sql": sql, "schema": schema, "rows": out_rows, "row_count": len(out_rows)}

# -------------------------
# LLM PIPELINE
# -------------------------
def ask(question: str) -> str:
    r1 = client.models.generate_content(
        model=MODEL,
        contents=SYSTEM_PROMPT + "\nUser: " + question,
        config=types.GenerateContentConfig(tools=[tool], temperature=0.1),
    )

    fc = None
    parts = (r1.candidates[0].content.parts or []) if r1.candidates else []
    for p in parts:
        if p.function_call and p.function_call.name == "execute_sql_query":
            fc = p.function_call
            break

    if not fc:
        return (r1.text or "").strip() or "No tool call was made."

    sql = dict(fc.args).get("sql_query", "")
    tool_result = execute_sql_query(sql)

    if "error" in tool_result:
        return f"Query rejected: {tool_result['error']}"

    r2 = client.models.generate_content(
        model=MODEL,
        contents=[
            types.Content(role="user", parts=[types.Part(text=SYSTEM_PROMPT)]),
            types.Content(role="user", parts=[types.Part(text="User: " + question)]),
            types.Content(
                role="tool",
                parts=[types.Part(function_response=types.FunctionResponse(
                    name="execute_sql_query",
                    response=tool_result
                ))],
            ),
        ],
        config=types.GenerateContentConfig(temperature=0.1),
    )

    return (r2.text or "").strip()

# -------------------------
# TELEGRAM WEBHOOK HANDLER (Cloud Function entry)
# -------------------------
def telegram_send(chat_id: int, text: str):
    requests.post(
        f"{TELEGRAM_API}/sendMessage",
        json={"chat_id": chat_id, "text": text[:3500]},
        timeout=15,
    )

@functions_framework.http
def telegram_webhook(request):
    update = request.get_json(silent=True) or {}

    msg = update.get("message") or update.get("edited_message")
    if not msg:
        return ("ok", 200)

    chat_id = msg["chat"]["id"]
    text = (msg.get("text") or "").strip()

    if not text:
        telegram_send(chat_id, "Send me a text question 🙂")
        return ("ok", 200)

    try:
        answer = ask(text)
    except Exception as e:
        answer = f"Error: {e}"

    telegram_send(chat_id, answer)
    return ("ok", 200)
