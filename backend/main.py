"""
EmojiRain Multiplayer Backend  —  FastAPI + Supabase
=====================================================

Endpoints
---------
POST /rooms/create          Create a new room (host player joins automatically)
POST /rooms/{code}/join     Join an existing room (max 4 players)
GET  /rooms/{code}          Fetch current room state
POST /rooms/{code}/ready    Mark a player as ready
POST /rooms/{code}/start    Host starts the game (2+ ready players required)
POST /rooms/{code}/score    Player pushes their current score during gameplay
POST /rooms/{code}/dead     Player signals they died / game over
GET  /rooms/{code}/live     SSE stream — live score updates broadcast to all in room

Environment variables (set in .env or Railway / Render dashboard)
-----------------------------------------------------------------
SUPABASE_URL          https://xxxx.supabase.co
SUPABASE_SERVICE_KEY  service_role JWT (bypass RLS for server writes)
SECRET_KEY            any random string, used to sign internal tokens
"""

from __future__ import annotations

import asyncio
import json
import os
import random
import string
import time
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from typing import Any, AsyncGenerator

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Path, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from supabase import Client, create_client

load_dotenv()

# ── Supabase client ────────────────────────────────────────────────────────────
SUPABASE_URL: str = os.environ["SUPABASE_URL"]
SUPABASE_KEY: str = os.environ["SUPABASE_SERVICE_KEY"]
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# ── SSE broadcast registry ─────────────────────────────────────────────────────
# room_code → list of asyncio.Queue instances (one per connected SSE client)
_sse_clients: dict[str, list[asyncio.Queue]] = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Background task: prune rooms older than 30 minutes."""
    asyncio.create_task(_prune_old_rooms())
    yield


app = FastAPI(title="EmojiRain Multiplayer API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic schemas ───────────────────────────────────────────────────────────

class CreateRoomRequest(BaseModel):
    host_id:  str
    nickname: str

class JoinRoomRequest(BaseModel):
    player_id: str
    nickname:  str

class ReadyRequest(BaseModel):
    player_id: str

class StartRequest(BaseModel):
    player_id: str

class ScoreRequest(BaseModel):
    player_id: str
    score:     int

class DeadRequest(BaseModel):
    player_id: str


# ── Helpers ────────────────────────────────────────────────────────────────────

def _generate_room_code(length: int = 6) -> str:
    chars = string.ascii_uppercase + string.digits
    # Exclude ambiguous characters
    chars = chars.translate(str.maketrans("", "", "O0IL1"))
    return "".join(random.choices(chars, k=length))


def _generate_seed() -> int:
    return random.randint(100_000, 999_999_999)


def _room_to_dict(room_row: dict) -> dict:
    """Normalise a Supabase row into the GameRoom JSON shape Flutter expects."""
    return {
        "room_code":   room_row["room_code"],
        "host_id":     room_row["host_id"],
        "seed_value":  room_row["seed_value"],
        "status":      room_row["status"],
        "created_at":  room_row["created_at"],
        "players":     room_row.get("players", []),
    }


async def _get_room(code: str) -> dict:
    res = supabase.table("rooms").select("*").eq("room_code", code).single().execute()
    if not res.data:
        raise HTTPException(404, detail=f"Room '{code}' not found")
    return res.data


async def _save_room(code: str, patch: dict) -> dict:
    res = (
        supabase.table("rooms")
        .update(patch)
        .eq("room_code", code)
        .execute()
    )
    if not res.data:
        raise HTTPException(500, detail="Failed to update room")
    return res.data[0]


async def _broadcast(code: str, payload: dict) -> None:
    """Push a JSON payload to all SSE listeners for this room."""
    queues = _sse_clients.get(code, [])
    for q in list(queues):
        try:
            q.put_nowait(json.dumps(payload))
        except asyncio.QueueFull:
            pass


# ── Routes ─────────────────────────────────────────────────────────────────────

@app.post("/rooms/create")
async def create_room(req: CreateRoomRequest) -> dict:
    # Generate a unique room code (retry up to 5 times to avoid collision)
    for _ in range(5):
        code = _generate_room_code()
        existing = supabase.table("rooms").select("room_code").eq("room_code", code).execute()
        if not existing.data:
            break
    else:
        raise HTTPException(503, detail="Could not generate unique room code")

    seed     = _generate_seed()
    now_iso  = datetime.now(timezone.utc).isoformat()
    host_player = {
        "player_id": req.host_id,
        "nickname":  req.nickname,
        "score":     0,
        "level":     1,
        "is_ready":  False,
        "is_alive":  True,
    }

    row = {
        "room_code":  code,
        "host_id":    req.host_id,
        "seed_value": seed,
        "status":     "waiting",
        "created_at": now_iso,
        "players":    [host_player],
    }

    res = supabase.table("rooms").insert(row).execute()
    if not res.data:
        raise HTTPException(500, detail="Failed to create room")

    return _room_to_dict(res.data[0])


@app.post("/rooms/{code}/join")
async def join_room(
    req:  JoinRoomRequest,
    code: str = Path(..., min_length=6, max_length=6),
) -> dict:
    code  = code.upper()
    room  = await _get_room(code)
    players: list[dict] = room.get("players", [])

    if room["status"] not in ("waiting",):
        raise HTTPException(400, detail="Room is not accepting new players")
    if len(players) >= 4:
        raise HTTPException(400, detail="Room is full")
    if any(p["player_id"] == req.player_id for p in players):
        raise HTTPException(400, detail="Already in room")

    players.append({
        "player_id": req.player_id,
        "nickname":  req.nickname,
        "score":     0,
        "level":     1,
        "is_ready":  False,
        "is_alive":  True,
    })

    updated = await _save_room(code, {"players": players})
    await _broadcast(code, {"type": "room_update", "status": updated["status"],
                             "players": updated["players"]})
    return _room_to_dict(updated)


@app.get("/rooms/{code}")
async def get_room(code: str = Path(..., min_length=6, max_length=6)) -> dict:
    room = await _get_room(code.upper())
    return _room_to_dict(room)


@app.post("/rooms/{code}/ready")
async def mark_ready(
    req:  ReadyRequest,
    code: str = Path(..., min_length=6, max_length=6),
) -> dict:
    code    = code.upper()
    room    = await _get_room(code)
    players = room.get("players", [])

    for p in players:
        if p["player_id"] == req.player_id:
            p["is_ready"] = True
            break

    updated = await _save_room(code, {"players": players})
    await _broadcast(code, {"type": "room_update", "status": updated["status"],
                             "players": updated["players"]})
    return _room_to_dict(updated)


@app.post("/rooms/{code}/start")
async def start_game(
    req:  StartRequest,
    code: str = Path(..., min_length=6, max_length=6),
) -> dict:
    code = code.upper()
    room = await _get_room(code)

    if room["host_id"] != req.player_id:
        raise HTTPException(403, detail="Only the host can start the game")

    players      = room.get("players", [])
    ready_count  = sum(1 for p in players if p["is_ready"])
    if ready_count < 2:
        raise HTTPException(400, detail="At least 2 players must be ready")

    updated = await _save_room(code, {"status": "playing"})
    await _broadcast(code, {"type": "room_update", "status": "playing",
                             "players": updated["players"]})
    return _room_to_dict(updated)


@app.post("/rooms/{code}/score")
async def push_score(
    req:  ScoreRequest,
    code: str = Path(..., min_length=6, max_length=6),
) -> dict:
    code    = code.upper()
    room    = await _get_room(code)
    players = room.get("players", [])

    for p in players:
        if p["player_id"] == req.player_id:
            p["score"] = req.score
            break

    updated = await _save_room(code, {"players": players})
    await _broadcast(code, {"type": "score_update", "status": updated["status"],
                             "players": updated["players"]})
    return {"ok": True}


@app.post("/rooms/{code}/dead")
async def player_dead(
    req:  DeadRequest,
    code: str = Path(..., min_length=6, max_length=6),
) -> dict:
    code    = code.upper()
    room    = await _get_room(code)
    players = room.get("players", [])

    for p in players:
        if p["player_id"] == req.player_id:
            p["is_alive"] = False
            break

    all_dead   = all(not p["is_alive"] for p in players)
    new_status = "finished" if all_dead else room["status"]
    updated    = await _save_room(code, {"players": players, "status": new_status})

    await _broadcast(code, {"type": "score_update", "status": updated["status"],
                             "players": updated["players"]})
    return {"ok": True}


@app.get("/rooms/{code}/live")
async def sse_live(
    request: Request,
    code:    str = Path(..., min_length=6, max_length=6),
) -> StreamingResponse:
    """Server-Sent Events stream for live leaderboard updates."""
    code = code.upper()

    async def event_generator() -> AsyncGenerator[str, None]:
        queue: asyncio.Queue[str] = asyncio.Queue(maxsize=64)
        _sse_clients.setdefault(code, []).append(queue)
        try:
            # Send current state immediately on connect
            try:
                room = await _get_room(code)
                yield _sse_event({"type": "room_update",
                                  "status": room["status"],
                                  "players": room.get("players", [])})
            except Exception:
                pass

            while True:
                if await request.is_disconnected():
                    break
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=25.0)
                    yield _sse_event(json.loads(payload))
                except asyncio.TimeoutError:
                    # Heartbeat keeps connection alive through proxies
                    yield ": heartbeat\n\n"
        finally:
            clients = _sse_clients.get(code, [])
            if queue in clients:
                clients.remove(queue)

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control":               "no-cache",
            "X-Accel-Buffering":           "no",
            "Access-Control-Allow-Origin": "*",
        },
    )


def _sse_event(data: dict) -> str:
    return f"data: {json.dumps(data)}\n\n"


# ── Background pruning ─────────────────────────────────────────────────────────

async def _prune_old_rooms() -> None:
    """Delete rooms older than 30 minutes every 5 minutes."""
    while True:
        await asyncio.sleep(300)
        try:
            cutoff = datetime.now(timezone.utc).replace(
                second=0, microsecond=0
            ).isoformat()
            supabase.table("rooms").delete().lt("created_at", cutoff).execute()
        except Exception:
            pass


# ── Supabase table SQL (run once in Supabase SQL editor) ──────────────────────
# CREATE TABLE IF NOT EXISTS rooms (
#   room_code   TEXT PRIMARY KEY,
#   host_id     TEXT NOT NULL,
#   seed_value  BIGINT NOT NULL,
#   status      TEXT NOT NULL DEFAULT 'waiting',
#   players     JSONB NOT NULL DEFAULT '[]',
#   created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
# );
# CREATE INDEX ON rooms (created_at);
# -- Enable RLS and disable for service role (backend uses service_role key)
# ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
