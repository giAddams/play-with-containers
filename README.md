# Play-with-containers

A containerized, multi-tier microservice architecture designed for inventory management and asynchronous billing processing.
---


## Key Vocabulary & Concepts

- **Container**: A lightweight, standalone package that includes everything needed to run a piece of software (code, runtime, libraries).
- **Image**: The read-only "blueprint" or template used to create a container.
- **Docker Compose**: A tool for defining and running multi-container applications using a single YAML file.
- **Dockerfile**: A text document containing all the commands a user could call on the command line to assemble an image.
- **Alpine Linux**: PostgreSQL for data durability
- **Service Discovery**: The process of containers finding each other using names (like inventory-app) instead of hardcoded IP addresses.
- **Gateway**: A server that acts as an API front-end, receiving requests and "proxying" them to the correct backend service.
- **Volume**: A persistent storage mechanism managed by Docker that lives outside the container's lifecycle.

### Stack

| Component              | Technology                |
| ---------------------- | ------------------------- |
| **Languages:**         | Python 3.11 (Flask)       |
| **Containerization:**  | Docker & Docker Compose   |
| **Database:**          | PostgreSQL 15             |
| **Message Broker:**    | RabbitMQ                  |
| **Base OS:**           | Alpine Linux(for ultra-   |
|                        | lightweight images)       |


---

### Reverse Proxy Pattern

The **API Gateway** acts as a **reverse proxy**, providing a single point of entry for all clients:

```
Clients (Multiple)          API Gateway              Backend Services
      │                         │                            │
      ├─► Single IP:Port ────►  │ (Reverse Proxy)            │
      │   192.168.56.10:3000    │                            │
      │                         ├─► /api/movies/* ─────────► Inventory API (8080)
      │                         │                            │
      │                         ├─► /api/billing ─────────► RabbitMQ Queue
      │                         │                            
      └──────────────────────┬──┘                            
                             │
                      Response routed
                      back to client
```

---

### Data Flow

**CRUD Operations :**

```
Client → API Gateway (3000) [Reverse Proxy]
       → Inventory API (8080) [HTTP Proxy Forward]
       → PostgreSQL movies DB
       ↓ (Response back through same path)
```

**Billing Operations (Orders):**

```
Client → API Gateway (3000)
       → RabbitMQ Queue
       ↓ (Asynchronously)
Billing API Consumer reads queue
       → PostgreSQL orders DB
       ↓ (Message durability - survives crashes)
```

---

## Project Structure

```
CRUD-MASTER/
│
├── README.md                           
├── CRUD_Master_README.md               
├── AUDIT_VERIFICATION_CHECKLIST.md     
│
├── Vagrantfile                         
├── .env                                
├── .gitignore                          
│
├── srcs/
│   ├── inventory-database/                
|   |   ├── Dockerfile             
│   │   └── entrypoint.sh
|   |
│   ├── billing-database/                
|   |   ├── Dockerfile             
│   │   └── entrypoint.sh
|   |
│   ├── rabbitmq-server/                
|   |   ├── Dockerfile             
│   │   └── entrypoint.sh
|   |                            
│   ├── api-gateway-app/                
│   │   ├── server.py                   
│   │   ├── requirements.txt
|   |   ├── Dockerfile             
│   │   └── app/__init__.py            
│   │
│   ├── inventory-app/                 
│   │   ├── server.py
|   |   ├── Dockerfile                      
│   │   ├── requirements.txt            
│   │   └── app/
│   │       ├── __init__.py             
│   │       ├── routes.py               
│   │       ├── models.py               
│   │       └── db.py                  
│   │
│   ├── billing-app/                   
│   │    ├── server.py
|   │    ├── Dockerfile                      
│   │    ├── requirements.txt            
│   │    └── app/
│   │        ├── __init__.py             
│   │        ├── consumer.py             
│   │        ├── models.py              
│   │        └── db.py                  
│   │
│   └── docker-compose.yml
│
├── scripts/                            
│   ├── setup_inventory.sh              
│   ├── setup_billing.sh                
│   └── setup_gateway.sh               
│
├── logs/                               
│   ├── inventory-api.log
│   ├── billing-api.log
│   └── gateway.log
│
├── CRUD_Master.postman_collection.json 
├── openapi.yaml                        
├── health_check_report.txt             
├── postman-results.json                
│
└── start_services.sh                   
```

---

## Services Overview

### 1. API Gateway (Gateway-VM)

**Port**: 3000  
**Purpose**: Reverse proxy - single entry point for all client requests  
**Technology**: Python + Flask  
**Pattern**: Reverse Proxy + HTTP Proxy

#### Features:

- **Reverse Proxy Pattern**: Receives all client requests at single URL (192.168.56.10:3000)
- **HTTP Proxy Implementation**: Forwards `/api/movies/*` requests to Inventory API backend
- **Service Abstraction**: Clients don't know about internal Inventory API address
- **Message Publisher**: Routes `/api/billing` to RabbitMQ for async processing
- **Health check endpoint**: `/health` for monitoring
- **Connection pooling and timeouts**: Reliable backend communication
- **Request forwarding**: Preserves HTTP methods, headers, query parameters, and body

#### Configuration:

```env
GATEWAY_IP=api-gateway-app
INVENTORY_IP=inventory-app
BILLING_IP=billing-app
```

---

### 2. Inventory API (Inventory-VM)

**Port**: 8080  
**Purpose**: Movie CRUD operations  
**Database**: PostgreSQL (movies DB)

#### Endpoints:

| Method | Endpoint              | Purpose           |
| ------ | --------------------- | ----------------- |
| POST   | `/api/movies`         | Create movie      |
| GET    | `/api/movies`         | List all movies   |
| GET    | `/api/movies?title=X` | Filter by title   |
| GET    | `/api/movies/{id}`    | Get single movie  |
| PUT    | `/api/movies/{id}`    | Update movie      |
| DELETE | `/api/movies/{id}`    | Delete movie      |
| DELETE | `/api/movies`         | Delete all movies |


---

### 3. Billing API (Billing-VM)

**Purpose**: Async order processing  
**Transport**: RabbitMQ message queue  
**Database**: PostgreSQL (orders DB)

#### Features:

- Consumes messages from `billing_queue`
- Processes orders asynchronously
- Durable queue (survives crashes)
- Automatic message replay on restart

#### Endpoint:

| Method | Endpoint       | Purpose                   |
| ------ | -------------- | ------------------------- |
| POST   | `/api/billing` | Queue order (via Gateway) |


---

## Infrastructure & Storage Services

### 4. Inventory Database (inventory-database)

**Role**: Permanent Movie Storage.
**Function**: Stores tables for movie titles, directors, and release years.
**Configuration**: Uses a custom Dockerfile and entrypoint.sh to initialize the movies database and inventory_user automatically.
**Persistence**: Backed by a Docker Volume to prevent data loss.

---

### 5. Billing Database (billing-database)

**Role**: Permanent Transaction Storage.
**Function**: Stores records of all processed bills and orders.
**Configuration**: Isolated from the Inventory DB to ensure that a failure in one service doesn't crash the other (Fault Isolation).

---

### 6. Message Broker (rabbitmq-server)

**Role**: The Communication Backbone.
**Function**: It manages the "Queue." When the Gateway needs the Billing app to do something, it doesn't call it directly; it drops a message here. This allows the system to handle high traffic without crashing.
**Technology**: RabbitMQ (AMQP Protocol).

---

## Creating the Images and Containers

Docker Compose reads your docker-compose.yml and the individual Dockerfiles in srcs/ folder to build the environment.

### 1. The Build & Up Command

Run the command on the /srcs directory:

 ```
docker-compose up --build -d
```
---

### 2. Verify Health

```
docker ps
```
---

## Configuration of .env Connection

For the services to talk to each other, they need the correct "addresses."

```
# Inside .env
INVENTORY_DB_HOST=inventory-database
BILLING_DB_HOST=billing-database
RABBITMQ_HOST=rabbitmq-server
INVENTORY_IP=inventory-app
BILLING_IP=billing-app
```

## Making it work with Postman

**Step 1: Add a Movie (The Write Test)**
**Method**: POST
**URL**: http://localhost:3000/api/movies
**Headers**: Content-Type: application/json
**Body (raw JSON)**:
```
{
  "title": "Interstellar",
  "director": "Christopher Nolan",
  "year": 2014
}
```
**Success**: You receive a 201 Created. This proves: Gateway → Inventory App → Inventory DB is working.

---

**Step 2: Fetch Movies (The Persistence Test)**
**Method**: GET
**URL**: http://localhost:3000/api/movies
**Success**: You see your movie in the list. This proves: Volumes are storing data correctly.

---

**Step 3: Trigger Billing (The Event Test)**
**Method**: POST
**URL**: http://localhost:3000/api/billing
**Body (raw JSON)**:
```
{
    "user_id": 1,
    "movie_id": 1,
    "total_amount": 9.99,
    "number_of_items": 4
}
```
**Success**: Postman returns 200 Accepted.

---

## Troubleshooting Common Issues

If it doesn't work immediately, check these two things:

**Check Logs**: If you get a 500 or 502 error, run:

```Bash
docker-compose logs -f [service-name]
```

Inside the Container: If you suspect the DB is empty, "jump into" it:
```Bash
docker exec -it inventory-database psql -U inventory_user -d movies
```