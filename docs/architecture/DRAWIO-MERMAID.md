# DrapeAI — draw.io Mermaid architecture

> **draw.io:** Arrange → Insert → Advanced → Mermaid → paste the block below.
> **Last updated:** 2026-08-08

## End-to-end (left → right)

```mermaid
flowchart LR
  subgraph L1["1 · Clients"]
    direction TB
    Flutter["Flutter<br/>Riverpod · GoRouter · Dio"]
    Admin["Admin<br/>Vite · React"]
  end

  subgraph L2["2 · Identity"]
    direction TB
    Firebase["Firebase Auth<br/>Google / OTP → JWT"]
  end

  subgraph L3["3 · Edge"]
    direction TB
    DNS["Cloudflare DNS"]
    Nginx["Nginx TLS<br/>:443 → :8000"]
  end

  subgraph L4["4 · API monolith"]
    direction TB
    MW["Middleware<br/>CORS · rate limit · security"]
    Routes["Routes<br/>auth · avatar · items · outfits<br/>try_on · lookbooks · admin"]
    Svc["Services<br/>upload · vision · rule_engine<br/>llm_ranker · try_on_job<br/>image_gen_provider · avatar"]
    MW --> Routes --> Svc
  end

  subgraph L5["5 · Persistence"]
    direction TB
    PG[("PostgreSQL + pgvector<br/>users · items · outfits<br/>try_on · prefs")]
    Redis[("Redis<br/>ARQ · cache · limits")]
    Store["R2 / local uploads<br/>images · avatar · results"]
  end

  subgraph L6["6 · AI and external"]
    direction TB
    Vision["Vision / garment split<br/>GPT-4o · Gemini"]
    OutfitAI["Outfit rank LLM"]
    TryOn["Try-on cascade<br/>RunPod IDM-VTON → CF<br/>→ NVIDIA → Gemini/Vertex<br/>→ OpenAI → composite"]
    Weather["Open-Meteo"]
    FCM["FCM push"]
    GPU["RunPod worker<br/>optional GPU"]
  end

  Flutter -->|sign-in| Firebase
  Flutter -->|Bearer JWT HTTPS| DNS
  Admin -->|admin JWT HTTPS| DNS
  Flutter -.->|dev LAN :8000| MW
  DNS --> Nginx --> MW
  MW -->|verify JWT| Firebase
  Svc --> PG
  Svc --> Redis
  Svc --> Store
  Svc --> Vision
  Svc --> OutfitAI
  Svc --> TryOn
  Svc --> Weather
  Svc --> FCM
  TryOn --> GPU
```

**Flow:** Clients → Firebase JWT → DNS/Nginx → FastAPI (middleware → routes → services) → Postgres/Redis/R2 and AI providers (vision, outfit rank, try-on cascade, weather, push).
