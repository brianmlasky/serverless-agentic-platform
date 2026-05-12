import os
import uuid
import time
import json
import httpx
from fastapi import FastAPI, HTTPException, Header, Request, Depends
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel
from typing import Optional, List, Any
from security import verify_iap_jwt

app = FastAPI(title="Agentic Platform API Gateway", version="2.0.4")

LITELLM_BASE_URL = os.getenv("LITELLM_BASE_URL", "http://litellm-gateway.litellm.svc.cluster.local:80")
LITELLM_MASTER_KEY = os.getenv("LITELLM_MASTER_KEY", "")
AGENT_MODEL = os.getenv("AGENT_MODEL", "claude-sonnet")
COST_CENTER = os.getenv("COST_CENTER", "agentic-platform.dev")

# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class Message(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    model: str
    messages: List[Message]
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = 1024

class ChatResponse(BaseModel):
    id: str
    object: str
    model: str
    choices: list

class AgentRunRequest(BaseModel):
    query: str
    model: Optional[str] = None
    max_iterations: Optional[int] = 5

class ActionTrace(BaseModel):
    iteration: int
    thought: str
    tool: Optional[str] = None
    tool_input: Optional[dict] = None
    observation: Optional[str] = None
    latency_ms: float

class AgentRunResponse(BaseModel):
    trace_id: str
    cost_center: str
    query: str
    answer: str
    model: str
    iterations: int
    action_traces: List[ActionTrace]

# ---------------------------------------------------------------------------
# Tool definitions
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "gke_cluster_info",
            "description": (
                "Returns metadata about the GKE cluster: name, location, version, "
                "status, and node pool summary."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "pod_status",
            "description": (
                "Returns the current status of all pods in a given Kubernetes namespace. "
                "Use this to check if services are healthy."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "namespace": {
                        "type": "string",
                        "description": "Kubernetes namespace to inspect, e.g. 'agentic' or 'litellm'.",
                    }
                },
                "required": ["namespace"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "aws_account_info",
            "description": (
                "Returns AWS account metadata: account ID, aliases, and the IAM role "
                "used by the LiteLLM gateway for Bedrock access."
            ),
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    },
    {
        "type": "function",
        "function": {
            "name": "cost_tracker",
            "description": (
                "Returns simulated cost and usage metrics for the agentic platform, "
                "broken down by cost center and service."
            ),
            "parameters": {
                "type": "object",
                "properties": {
                    "cost_center": {
                        "type": "string",
                        "description": "Cost center label to filter by, e.g. 'agentic-platform.dev'.",
                    }
                },
                "required": [],
            },
        },
    },
]

# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

def run_tool(name: str, tool_input: dict) -> str:
    if name == "gke_cluster_info":
        return json.dumps({
            "cluster_name": "dev-gke-cluster",
            "location": "us-central1",
            "version": "v1.35.3-gke.1389000",
            "status": "RUNNING",
            "autopilot": True,
            "node_pools": [
                {"name": "pool-1", "status": "RUNNING"},
                {"name": "pool-2", "status": "RUNNING"},
                {"name": "pool-3", "status": "RUNNING"},
            ],
            "project": "alert-hall-466720-c0",
        })
    elif name == "pod_status":
        namespace = tool_input.get("namespace", "default")
        pod_data = {
            "agentic": [
                {"name": "api-gateway-68c7854d97-25t55", "status": "Running", "ready": "1/1", "restarts": 0},
            ],
            "litellm": [
                {"name": "litellm-gateway-7d6f8b9c4d-xk2pq", "status": "Running", "ready": "1/1", "restarts": 0},
            ],
        }
        pods = pod_data.get(namespace, [])
        return json.dumps({"namespace": namespace, "pod_count": len(pods), "pods": pods})
    elif name == "aws_account_info":
        return json.dumps({
            "account_id": "229502947368",
            "aliases": ["agentic-platform-dev"],
            "bedrock_role": "arn:aws:iam::229502947368:role/litellm-bedrock-role",
            "irsa_service_account": "litellm-sa",
            "region": "us-east-1",
        })
    elif name == "cost_tracker":
        cost_center_filter = tool_input.get("cost_center", COST_CENTER)
        return json.dumps({
            "cost_center": cost_center_filter,
            "period": "current_month",
            "services": {
                "bedrock_inference": {"usd": 4.82, "requests": 1240},
                "gke_compute": {"usd": 18.34, "hours": 312},
                "artifact_registry": {"usd": 0.12, "gb_stored": 4.8},
            },
            "total_usd": 23.28,
        })
    else:
        return json.dumps({"error": f"Unknown tool: {name}"})

# ---------------------------------------------------------------------------
# LiteLLM call helper
# ---------------------------------------------------------------------------

async def llm_chat(messages: list, tools: list, model: str) -> dict:
    headers = {
        "Authorization": f"Bearer {LITELLM_MASTER_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "messages": messages,
        "temperature": 0.2,
        "max_tokens": 1024,
    }
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            resp = await client.post(
                f"{LITELLM_BASE_URL}/v1/chat/completions",
                json=payload,
                headers=headers,
            )
            resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
        except httpx.RequestError as e:
            raise HTTPException(status_code=503, detail=f"LiteLLM unreachable: {str(e)}")
    return resp.json()

# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/health")
async def health():
    return {"status": "ok", "service": "api-gateway", "version": "2.0.4"}

# ---------------------------------------------------------------------------
# GET /v1/models — OpenAI-compatible discovery, no IAP required
# ---------------------------------------------------------------------------

@app.get("/v1/models")
async def list_models():
    headers = {
        "Authorization": f"Bearer {LITELLM_MASTER_KEY}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            resp = await client.get(
                f"{LITELLM_BASE_URL}/v1/models",
                headers=headers,
            )
            resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"LiteLLM /v1/models error: {e.response.text}",
            )
        except httpx.RequestError as e:
            raise HTTPException(status_code=503, detail=f"LiteLLM unreachable: {str(e)}")
    return JSONResponse(content=resp.json())

# ---------------------------------------------------------------------------
# POST /v1/chat/completions — OpenAI-compatible, full proxy with streaming
# ---------------------------------------------------------------------------

@app.post("/v1/chat/completions")
async def chat_completions(
    request: Request,
    iap_claims: dict = Depends(verify_iap_jwt),
):
    try:
        body = await request.json()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid JSON body")

    headers = {
        "Authorization": f"Bearer {LITELLM_MASTER_KEY}",
        "Content-Type": "application/json",
    }

    is_streaming = body.get("stream", False)

    if is_streaming:
        async def stream_generator():
            async with httpx.AsyncClient(timeout=120.0) as client:
                async with client.stream(
                    "POST",
                    f"{LITELLM_BASE_URL}/v1/chat/completions",
                    json=body,
                    headers=headers,
                ) as resp:
                    if resp.status_code >= 400:
                        error_body = await resp.aread()
                        yield error_body
                        return
                    async for chunk in resp.aiter_bytes():
                        yield chunk

        return StreamingResponse(stream_generator(), media_type="text/event-stream")

    async with httpx.AsyncClient(timeout=120.0) as client:
        try:
            resp = await client.post(
                f"{LITELLM_BASE_URL}/v1/chat/completions",
                json=body,
                headers=headers,
            )
            resp.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"LiteLLM error: {e.response.text}",
            )
        except httpx.RequestError as e:
            raise HTTPException(status_code=503, detail=f"LiteLLM unreachable: {str(e)}")

    return JSONResponse(content=resp.json())

# ---------------------------------------------------------------------------
# POST /v1/chat — legacy route, kept for backward compat
# ---------------------------------------------------------------------------

@app.post("/v1/chat", response_model=ChatResponse)
async def chat(
    payload: ChatRequest,
    authorization: Optional[str] = Header(None),
    iap_claims: dict = Depends(verify_iap_jwt),
):
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = authorization.removeprefix("Bearer ")
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            response = await client.post(
                f"{LITELLM_BASE_URL}/v1/chat/completions",
                json=payload.model_dump(),
                headers=headers,
            )
            response.raise_for_status()
        except httpx.HTTPStatusError as e:
            raise HTTPException(status_code=e.response.status_code, detail=e.response.text)
        except httpx.RequestError as e:
            raise HTTPException(status_code=503, detail=f"LiteLLM unreachable: {str(e)}")

    return JSONResponse(content=response.json())

# ---------------------------------------------------------------------------
# POST /v1/agent/run — ReAct loop
# ---------------------------------------------------------------------------

@app.post("/v1/agent/run", response_model=AgentRunResponse)
async def agent_run(
    payload: AgentRunRequest,
    iap_claims: dict = Depends(verify_iap_jwt),
):
    trace_id = str(uuid.uuid4())
    model = payload.model or AGENT_MODEL
    max_iterations = min(payload.max_iterations or 5, 10)

    system_prompt = (
        "You are a helpful infrastructure assistant for the Agentic Platform. "
        "You have access to tools that can query the GKE cluster, pod status, "
        "AWS account info, and cost data. "
        "Use the tools to answer the user's question accurately. "
        "When you have enough information, provide a clear final answer."
    )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": payload.query},
    ]

    action_traces: List[ActionTrace] = []
    iteration = 0
    final_answer = ""

    while iteration < max_iterations:
        iteration += 1
        iter_start = time.monotonic()

        llm_response = await llm_chat(messages, TOOLS, model)
        choice = llm_response["choices"][0]
        message = choice["message"]
        messages.append(message)

        finish_reason = choice.get("finish_reason", "")
        tool_calls = message.get("tool_calls") or []
        content = message.get("content") or ""
        latency_ms = (time.monotonic() - iter_start) * 1000

        if finish_reason == "stop" or not tool_calls:
            action_traces.append(ActionTrace(
                iteration=iteration,
                thought=content,
                tool=None,
                tool_input=None,
                observation=None,
                latency_ms=round(latency_ms, 2),
            ))
            final_answer = content
            break

        for tc in tool_calls:
            tool_name = tc["function"]["name"]
            try:
                tool_input = json.loads(tc["function"].get("arguments", "{}"))
            except json.JSONDecodeError:
                tool_input = {}

            tool_start = time.monotonic()
            observation = run_tool(tool_name, tool_input)
            tool_latency_ms = (time.monotonic() - tool_start) * 1000

            action_traces.append(ActionTrace(
                iteration=iteration,
                thought=content,
                tool=tool_name,
                tool_input=tool_input,
                observation=observation,
                latency_ms=round(latency_ms + tool_latency_ms, 2),
            ))

            messages.append({
                "role": "tool",
                "tool_call_id": tc["id"],
                "content": observation,
            })

    else:
        messages.append({
            "role": "user",
            "content": "Please summarize what you found and give your best answer now.",
        })
        llm_response = await llm_chat(messages, TOOLS, model)
        final_answer = llm_response["choices"][0]["message"].get("content", "Unable to determine answer.")

    return AgentRunResponse(
        trace_id=trace_id,
        cost_center=COST_CENTER,
        query=payload.query,
        answer=final_answer,
        model=model,
        iterations=iteration,
        action_traces=action_traces,
    )
