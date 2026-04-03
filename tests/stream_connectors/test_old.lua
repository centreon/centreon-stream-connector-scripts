function init(params)
  broker_log:set_parameters(2, '/tmp/test-LUA.log')
  broker_log:info(0, 'lua start test')
end

function write(e)
  if e._type == 65541 or e._type == 65572 then
    broker_log:info(0, 'downtime event detected')
  elseif e._type == 65550 or e._type == 65538 then
    broker_log:info(0, 'host status event detected')
  elseif e._type == 65560 or e._type == 65565 then
    broker_log:info(0, 'service status event detected')
  else
    return true
  end
  broker_log:info(0, 'event type: '.. e._type)
  broker_log:info(0, 'configuration of ('.. e.host_id.. ','.. e.service_id.. ')')
  local svc = broker_cache:get_service(e.host_id,e.service_id)
  broker_log:info(0, broker.json_encode(svc))
  return true
end
