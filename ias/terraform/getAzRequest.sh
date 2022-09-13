#!/bin/bash
echo "{\"id\": $(az monitor app-insights web-test show -g brief4_QB -n requesthttp-insights-app | jq '.id' )}"