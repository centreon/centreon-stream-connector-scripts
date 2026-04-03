#!/bin/bash

function login_to_centreon_api() {
  ## Base URL
  base_url="http://127.0.0.1:80/centreon/api"
  ## Get Centreon version:
  centreon_version=$(curl -s "$base_url/latest/platform/versions" | jq -r '.web | "\(.major).\(.minor)"')
  ## API URL with version
  base_url="$base_url/v$centreon_version"
  ## Login:
  CENTREON_USER="admin"
  CENTREON_PASS="Centreon!2021"
  token=$(curl -X POST -H "Content-Type: application/json" -d "{\"security\": {\"credentials\": {\"login\": \"$CENTREON_USER\", \"password\": \"$CENTREON_PASS\"}}}" -s "$base_url/login" | jq -r '.security.token' || { echo "Failed to retrieve token"; exit 1; })
}

# Create host and services
function create_host() {
  ## Get monitoring server id
  server_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/configuration/monitoring-servers" | jq -r '.result[0].id')
  ## Get the passive host template id
  host_template_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/configuration/hosts/templates" | jq -r '.result[] | select(.name == "generic-passive-host-custom") | .id')
  ## Create a host:
  host_id=$(curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"monitoring_server_id\": $server_id, \"name\": \"Host1\", \"address\": \"127.0.0.1\", \"templates\": [$host_template_id]}" -s "$base_url/configuration/hosts" | jq -r '.id')
}

function create_services() {
  local host_id=$1
  ## Get the passive service template id
  service_template_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/configuration/services/templates" | jq -r '.result[] | select(.name == "generic-passive-service-custom") | .id')
  ## Create 3 passive services for the host
  service1_id=$(curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"name\": \"Service1H2\", \"host_id\": $host_id, \"service_template_id\": $service_template_id}" -s "$base_url/configuration/services" | jq -r '.id')
  service2_id=$(curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"name\": \"Service2H2\", \"host_id\": $host_id, \"service_template_id\": $service_template_id}" -s "$base_url/configuration/services" | jq -r '.id')
  service3_id=$(curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"name\": \"Service3H2\", \"host_id\": $host_id, \"service_template_id\": $service_template_id}" -s "$base_url/configuration/services" | jq -r '.id')
}

## Reload conf
function reload_configuration() {
  curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/configuration/monitoring-servers/generate-and-reload"
}

# Save ids in a file
function save_ids() {
  echo "server_id=\"$server_id\"" > /home/save_vars
  echo "host_id=\"$host_id\"" >> /home/save_vars
  echo "service1_id=\"$service1_id\"" >> /home/save_vars
  echo "service2_id=\"$service2_id\"" >> /home/save_vars
  echo "service3_id=\"$service3_id\"" >> /home/save_vars
}

# Get vars after reboot
function reload_ids() {
  ## Reload ids
  source /home/save_vars
}

# Check host and services
function check_host_and_services() {
  ## Check host
  curl -X POST -H "X-AUTH-TOKEN: $token" -d '{"is_forced": true}' -s "$base_url/monitoring/hosts/$host_id/check"
  ## Check services
  curl -X POST -H "X-AUTH-TOKEN: $token" -d "[{\"is_forced\": true, \"resource_id\": $service1_id, \"parent_resource_id\": $host_id}, {\"is_forced\": true, \"resource_id\": $service2_id, \"parent_resource_id\": $host_id}, {\"is_forced\": true, \"resource_id\": $service3_id, \"parent_resource_id\": $host_id}]" -s "$base_url/monitoring/services/check"
}

# Submit host status
function submit_host_status() {
  ## Host status
  ## 0 - UP, 1 - DOWN, 2 - UNREACHABLE
  curl -X POST -H "X-AUTH-TOKEN: $token" -d '{"status": 0}' -s "$base_url/monitoring/hosts/$host_id/submit"
}

# Submit services status
function submit_services_status() {
  ## Service status
  ## 0 - OK, 1 - WARNING, 2 - CRITICAL, 3 - UNKNOWN
  curl -X POST -H "X-AUTH-TOKEN: $token" -d '{"status": 1}' -s "$base_url/monitoring/hosts/$host_id/services/$service1_id/submit"
  curl -X POST -H "X-AUTH-TOKEN: $token" -d '{"status": 1}' -s "$base_url/monitoring/hosts/$host_id/services/$service2_id/submit"
  curl -X POST -H "X-AUTH-TOKEN: $token" -d '{"status": 1}' -s "$base_url/monitoring/hosts/$host_id/services/$service3_id/submit"
}

# Set host downtime
function set_host_downtime() {
  start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  end_time=$(date -u -d "+5 minutes" +"%Y-%m-%dT%H:%M:%SZ")
  # Set host downtime
  curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"start_time\": \"$start_time\", \"end_time\": \"$end_time\", \"is_fixed\": true, \"duration\": 3600, \"comment\": \"Downtime set by admin\", \"with_services\": true}" -s "$base_url/monitoring/hosts/$host_id/downtimes"
}

# Set services downtimes
function set_services_downtimes() {
  start_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  end_time=$(date -u -d "+5 minutes" +"%Y-%m-%dT%H:%M:%SZ")
  # Set service downtimes
  curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"start_time\": \"$start_time\", \"end_time\": \"$end_time\", \"is_fixed\": true, \"duration\": 3600, \"comment\": \"Downtime set by admin\"}" -s "$base_url/monitoring/hosts/$host_id/services/$service1_id/downtimes"
  curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"start_time\": \"$start_time\", \"end_time\": \"$end_time\", \"is_fixed\": true, \"duration\": 3600, \"comment\": \"Downtime set by admin\"}" -s "$base_url/monitoring/hosts/$host_id/services/$service2_id/downtimes"
  curl -X POST -H "X-AUTH-TOKEN: $token" -d "{\"start_time\": \"$start_time\", \"end_time\": \"$end_time\", \"is_fixed\": true, \"duration\": 3600, \"comment\": \"Downtime set by admin\"}" -s "$base_url/monitoring/hosts/$host_id/services/$service3_id/downtimes"
}

# Cancel host downtimes
function cancel_host_downtime() {
  # Get host downtime ID
  host_downtime_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/hosts/$host_id/downtimes" | jq -r '.result[0].id')
  # Cancel host downtime
  curl -X DELETE -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/downtimes/$host_downtime_id"
}

# Cancel services downtimes
function cancel_services_downtimes() {
  # Get services downtimes IDs
  service1_downtime_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/hosts/$host_id/services/$service1_id/downtimes" | jq -r '.result[0].id')
  service2_downtime_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/hosts/$host_id/services/$service2_id/downtimes" | jq -r '.result[0].id')
  service3_downtime_id=$(curl -X GET -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/hosts/$host_id/services/$service3_id/downtimes" | jq -r '.result[0].id')
  # Cancel service downtimes
  curl -X DELETE -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/downtimes/$service1_downtime_id"
  curl -X DELETE -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/downtimes/$service2_downtime_id"
  curl -X DELETE -H "X-AUTH-TOKEN: $token" -s "$base_url/monitoring/downtimes/$service3_downtime_id"
}


# Menu to choose between creating host/services, reload ids after reboot, checking host/services or submitting status
# Options: 1 - Create host/services, 2 - Reload ids after reboot, 3 - Check host/services, 4 - Submit host status, 5 - Submit services status
# 6 - Set host downtime, 7 - Set services downtimes, 8 - Cancel host downtime, 9 - Cancel services downtimes
echo "Choose an option:"
echo "1 - Create host and services"
echo "2 - Reload ids after reboot"
echo "3 - Check host and services"
echo "4 - Submit host status"
echo "5 - Submit services status"
echo "6 - Set host downtime"
echo "7 - Set services downtimes"
echo "8 - Cancel host downtime"
echo "9 - Cancel services downtimes"
read -r option
if [ "$option" -eq 1 ]; then
    echo "Creating host and services..."
    login_to_centreon_api
    create_host
    create_services "$host_id"
    reload_configuration
    save_ids
elif [ "$option" -eq 2 ]; then
    echo "Reloading ids after reboot..."
    login_to_centreon_api
    reload_ids
elif [ "$option" -eq 3 ]; then
    echo "Checking host and services..."
    reload_ids
    login_to_centreon_api
    check_host_and_services
elif [ "$option" -eq 4 ]; then
    echo "Submitting host status..."
    reload_ids
    login_to_centreon_api
    submit_host_status
elif [ "$option" -eq 5 ]; then
    echo "Submitting services status..."
    reload_ids
    login_to_centreon_api
    submit_services_status
elif [ "$option" -eq 6 ]; then
    echo "Setting host downtime..."
    reload_ids
    login_to_centreon_api
    set_host_downtime
elif [ "$option" -eq 7 ]; then
    echo "Setting services downtimes..."
    reload_ids
    login_to_centreon_api
    set_services_downtimes
elif [ "$option" -eq 8 ]; then
    echo "Cancelling host downtime..."
    reload_ids
    login_to_centreon_api
    cancel_host_downtime
elif [ "$option" -eq 9 ]; then
    echo "Cancelling services downtimes..."
    reload_ids
    login_to_centreon_api
    cancel_services_downtimes
else
    echo "Invalid option"
    exit 1
fi
