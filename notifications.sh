#!/bin/bash

# https://github.com/Sweets/tiramisu
# https://github.com/dudik/herbe
# https://github.com/stedolan/jq

limit="\n"

while read -r line; do
    _summary=$(echo $line | jq .summary | sed 's/^.//' | sed 's/.$//')$limit
    summary=();
    
    while [[ $_summary ]]; do
        summary+=( "${_summary%%"$limit"*}" );
        _summary=${_summary#*"$limit"};
    done;

    _body=$(echo $line | jq .body | sed 's/^.//' | sed 's/.$//')$limit
    body=();

    while [[ $_body ]]; do
        body+=( "${_body%%"$limit"*}" );
        _body=${_body#*"$limit"};
    done;

    action=$(echo $line | jq .action | tr '"' ' ')

    IFS=''

    herbe ${summary[@]} " " ${body[@]} && $action &
done < <(tiramisu -j)
