# Kong Newrelic-insights plugin

## Newrelic Insights example

<img src="newrelic-insights-example.jpg" align="center" />

## Test with kong-vagrant VM

Don't forget to prepare the kong software for developement

    cd /kong && make dev

Make sure your newrelic plugin is available in Kong plugins folder

    ln -sfn /kong-plugin/kong-plugin-newrelic-insights/kong/plugins/newrelic-insights /kong/kong/plugins/newrelic-insights

Tell kong to use the Newrelic plugin and record logs in debug mode

    export KONG_CUSTOM_PLUGINS="newrelic-insights" && export KONG_LOG_LEVEL=debug && export KONG_PREFIX=/kong/servroot

Easy commands to test the plugin

    kong migrations up
    kong start
    
    Test the plugin not authenticated
    curl -i -X POST   --url http://localhost:8001/apis/   --data 'name=mockbin'   --data 'upstream_url=http://mockbin.org/request'   --data 'uris=/mockbin'
    curl -i -X POST   --url http://localhost:8001/apis/mockbin/plugins/   --data 'name=newrelic-insights' --data 'config.api_key=YOUR-NEWRELIC-API-KEY' --data 'config.account_id=YOUR-NEWRELIC-ACCOUNT-ID' --data 'config.environment_name=dev'
    curl "0.0.0.0:8000/mockbin?yeah=baby" --data '{"someVariables": "some value"}'
   
    
    Test the plugin authenticated
    curl -i -X POST   --url http://localhost:8001/consumers/   --data 'username=testconsumer'
    curl -i -X POST   --url http://localhost:8001/apis/mockbin/plugins/   --data 'name=key-auth' --data 'config.key_names=api_key'
    curl -i -X POST   --url http://localhost:8001/consumers/testconsumer/key-auth --data 'key=test123'
    curl "0.0.0.0:8000/mockbin?yeah=baby&api_key=test123" --data '{"someVariables": "some value"}'
    
    Restart your tests
    curl -i -X DELETE   --url http://localhost:8001/apis/mockbin
    curl -i -X DELETE   --url http://localhost:8001/consumers/testconsumer
    
# Ready for luarocks deployment 
    
   https://luarocks.org/modules/JnMik/kong-plugin-newrelic-insights
   
# To install in Kong while running in Docker Container

    RUN yum install -y unzip
    RUN cd /usr/local/share/lua/5.1/kong && luarocks install kong-plugin-newrelic-insights
    
# Known limitations or bug

    Plugin will try to determine which user is using the api gateway based on the key-auth plugin, and will 
    look for the "api_key" parameter in query string. Using another auth method than this will record
    events with "NOT AUTHENTICATED" value in the authenticated_consumers column. This should be improve eventually. 
    You are welcome to open a PR to fix this limitation if it's a concern for your usage.
