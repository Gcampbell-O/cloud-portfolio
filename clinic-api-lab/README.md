# Clinic API: Spring Boot on App Service, Azure SQL with a managed identity

A small Java REST API deployed to **Azure App Service (Linux, Java 17)**. It reads from **Azure SQL Database** using the web app's **system-assigned managed identity**, so **no username or password exists anywhere** in code, config or the connection string.

I built it as a learning lab (November 2026) to understand how a Java application runs, connects and is secured on Azure. Java and Spring Boot were new to me; the Azure side builds on my AZ-104 work.

## Architecture

```
Browser / curl
     │  HTTPS 443
     ▼
Azure App Service (F1, Linux, Java 17)
  └─ Spring Boot app (embedded Tomcat)
       ├─ GET /api/clinics         → all clinics
       ├─ GET /api/clinics/{id}    → one clinic, or 404
       └─ GET /actuator/health     → liveness / readiness
     │  TLS, port 1433, authentication = managed identity
     ▼
Azure SQL Database (serverless, free offer, AutoPause)
  └─ dbo.Clinics   (app identity has db_datareader only)
```

## What it demonstrates

| Area | How |
|---|---|
| **Passwordless database access** | System-assigned managed identity. The SQL server uses **Entra-only authentication**, so its generated SQL admin login is disabled |
| **Least privilege** | The app's contained database user (`FROM EXTERNAL PROVIDER`) has **`db_datareader`** only: it can read, not change or delete |
| **Configuration from the environment** | The JDBC URL is an App Service app setting (`SPRING_DATASOURCE_URL`), not code. The same `.jar` runs anywhere |
| **SQL injection prevention** | Parameterized queries (`WHERE Id = :id` plus `.param()`) through Spring's `JdbcClient` |
| **Correct REST behavior** | 200 with JSON for a match, **404** when the clinic doesn't exist |
| **Health probes** | Spring Boot Actuator `/actuator/health` with liveness and readiness groups |
| **Network hygiene** | The temporary query editor client-IP firewall rule was removed after setup |
| **Cost control** | App Service F1 (free) and the Azure SQL free offer with `AutoPause` (verified `useFreeLimit = True`) |

## Code

| File | Purpose |
|---|---|
| [`ClinicController.java`](src/main/java/com/gcampbell/clinic_api/ClinicController.java) | The REST endpoints. `JdbcClient` arrives through constructor injection |
| [`Clinic.java`](src/main/java/com/gcampbell/clinic_api/Clinic.java) | A Java record: the shape of one clinic |
| [`pom.xml`](pom.xml) | Spring Boot starters (web, actuator, jdbc), the Microsoft SQL Server JDBC driver, and `azure-identity` for managed identity authentication |
| [`sql/setup.sql`](sql/setup.sql) | Table, sample data, and the read-only database user for the app's identity |

The data is fictional sample data.

## Build and deploy (Azure Cloud Shell, Bash)

```bash
# Build (the default context test needs the database, so it's skipped here)
mvn -q -DskipTests package

# App Service
RG=rg-clinic-api-lab; LOC=centralus; PLAN=plan-clinic-api; APP=clinic-api-$RANDOM
az group create -n $RG -l $LOC
az appservice plan create -n $PLAN -g $RG --is-linux --sku F1
az webapp create -n $APP -g $RG -p $PLAN --runtime "JAVA:17-java17"

# Azure SQL: Entra-only, free offer
SQLSRV=sql-clinic-$RANDOM; DB=clinicdb
az sql server create -n $SQLSRV -g $RG -l $LOC --enable-ad-only-auth \
  --external-admin-principal-type User \
  --external-admin-name "$(az ad signed-in-user show --query userPrincipalName -o tsv)" \
  --external-admin-sid "$(az ad signed-in-user show --query id -o tsv)"
az sql db create -g $RG -s $SQLSRV -n $DB --edition GeneralPurpose --family Gen5 --capacity 2 \
  --compute-model Serverless --use-free-limit --free-limit-exhaustion-behavior AutoPause
az sql server firewall-rule create -g $RG -s $SQLSRV -n AllowAzureServices \
  --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0

# Managed identity, then run sql/setup.sql in the portal Query editor (as the Entra admin)
az webapp identity assign -g $RG -n $APP

# Point the app at the database: no credentials in the string
az webapp config appsettings set -g $RG -n $APP --settings \
  SPRING_DATASOURCE_URL="jdbc:sqlserver://$SQLSRV.database.windows.net:1433;database=$DB;encrypt=true;trustServerCertificate=false;hostNameInCertificate=*.database.windows.net;loginTimeout=30;authentication=ActiveDirectoryManagedIdentity;"

az webapp deploy -g $RG -n $APP --src-path target/clinic-api-0.0.1-SNAPSHOT.jar --type jar
```

## Verification

The app's original version served a hard-coded list of clinics 1–4. Clinic 5 was inserted **only in the database**, so returning it proves the deployed app reads from Azure SQL through its managed identity.

```
$ curl -s https://<app>.azurewebsites.net/api/clinics/5
{"id":5,"name":"Sample Mid-Plains Clinic","city":"North Platte","services":"Primary care, dental"}

$ curl -s -o /dev/null -w "%{http_code}\n" https://<app>.azurewebsites.net/api/clinics/99
404

$ curl -s https://<app>.azurewebsites.net/actuator/health
{"groups":["liveness","readiness"],"status":"UP"}
```

## What broke and how it was fixed

| Symptom | Evidence | Cause and fix |
|---|---|---|
| The app exited on startup (`Exit 1`), yet `curl localhost:8080` returned **401 Unauthorized** | `app.log`: *"Web server failed to start. Port 8080 was already in use."* | Another Cloud Shell process owned port 8080 and answered the request. Ran with `--server.port=8081`. **A response doesn't prove *your* service answered:** check the process and its log |
| `mvn package` failed: *"there is no POM in this directory"* | The prompt and the error both showed the wrong folder | A garbled paste skipped the `mkdir`/`cd`. Re-ran it from the project folder |
| Source files written to a path that didn't exist | `find` showed the package folder was `clinic_api`, not `clinicapi` | A regenerated project without `packageName` got Initializr's default. Matched the folder and the `package` line, since Spring only scans the main class's package |
| `az` commands failed: *"--resource-group/-g: expected one argument"* | — | Cloud Shell had reset (it's ephemeral), so the shell variables were empty. Set them again |

## Production gaps (deliberate, for a lab)

- **Network:** `AllowAzureServices` (0.0.0.0) admits any Azure-hosted client, including other tenants' resources. In production: **disable public access**, add a **private endpoint** for SQL, App Service **VNet integration** (not available on F1), and a **private DNS zone**.
- **Deployment:** manual `az webapp deploy`. Next step: a CI/CD pipeline (build → artifact → deploy to a staging **slot** → swap) using OIDC, like my [three-tier IaC pipeline](../three-tier-network-iac/).
- **Monitoring:** add Application Insights (the Java agent) and an App Service **Health check** on `/actuator/health` (Basic tier and up).
- **Front end:** a React client on Azure Static Web Apps, with CORS restricted to its domain.

## Cost and teardown

App Service F1 and the Azure SQL free offer: **$0** for the lab. Teardown: `az group delete -n $RG --yes`.
