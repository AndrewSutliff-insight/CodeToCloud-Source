GH_ACCESS_TOKEN=$CR_PAT
SUFFIX="aes"
RESOURCE_GROUP_NAME="fabrikam-rg-"$SUFFIX
DB_NAME="fabrikam-cdb-"$SUFFIX
WEBAPP_NAME="fabrikam-webapp-"$SUFFIX
PLAN_NAME="fabrikam-plan-"$SUFFIX
APP_INSIGHTS="fabrikamai-"$SUFFIX
LOCATION1="eastus"
LOCATION2="eastus2"

az group create -l $LOCATION1 -n $RESOURCE_GROUP_NAME
az cosmosdb create \
        --name $DB_NAME \
        --resource-group $RESOURCE_GROUP_NAME \
        --locations regionName=$LOCATION1 failoverPriority=0 isZoneRedundant=False \
        --locations regionName=$LOCATION2 failoverPriority=1 isZoneRedundant=True \
        --enable-multiple-write-locations \
        --kind MongoDB 

az appservice plan create --name $PLAN_NAME --resource-group $RESOURCE_GROUP_NAME --sku S1 --is-linux

az webapp create --resource-group $RESOURCE_GROUP_NAME --plan $PLAN_NAME --name $WEBAPP_NAME -i nginx

# MONGODB_CONNECTION=$(az cosmosdb keys list -n $DB_NAME  -g $RESOURCE_GROUP_NAME --type connection-strings \
# --query "connectionStrings[?description=='Primary MongoDB Connection String'].connectionString" | tr -d '\n',' ','[',']','\"' | sed s/\?/contentdb\?/)
# docker run --rm -e MONGODB_CONNECTION=$MONGODB_CONNECTION ghcr.io/andrewsutliff-insight/fabrikam-init

az extension add --name application-insights
AI=$(az monitor app-insights component show --app $APP_INSIGHTS --resource-group $RESOURCE_GROUP_NAME)
AI_KEY=$(echo $AI | jq -r '.instrumentationKey')
AI_CONNECTION=$(echo $AI | jq -r '.connectionString')

az webapp config appsettings set -n $WEBAPP_NAME -g $RESOURCE_GROUP_NAME \
--settings MONGODB_CONNECTION=$MONGODB_CONNECTION \
    APPINSIGHTS_INSTRUMENTATIONKEY=$AI_KEY \
    APPINSIGHTS_PROFILEFEATURE_VERSION=1.0.0 \
    APPINSIGHTS_SNAPSHOTFEATURE_VERSION=1.0.0 \
    APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION \
    ApplicationInsightsAgent_EXTENSION_VERSION=~2 \
    DiagnosticServices_EXTENSION_VERSION=~3 \
    InstrumentationEngine_EXTENSION_VERSION=disabled \
    SnapshotDebugger_EXTENSION_VERSION=disabled \
    XDT_MicrosoftApplicationInsights_BaseExtensions=disabled \
    XDT_MicrosoftApplicationInsights_Mode=recommended \
    XDT_MicrosoftApplicationInsights_PreemptSdk=disabled

az webapp config container set \
    --docker-registry-server-password $GH_ACCESS_TOKEN \
    --docker-registry-server-url https://ghcr.io \
    --docker-registry-server-user notapplicable \
    --multicontainer-config-file docker-compose.yml \
    --multicontainer-config-type COMPOSE \
    --name $WEBAPP_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --enable-app-service-storage true \
