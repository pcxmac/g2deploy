#!/bin/sh

PUBLIC_IP=`curl -s https://ipinfo.io/ip`
# Call the geolocation API and capture the output

curl -s https://ipvigilante.com/${PUBLIC_IP} | jq '.data.latitude, .data.longitude, .data.city_name, .data.country_name' | while read -r LATITUDE; do
	 read -r LONGITUDE
	 read -r CITY
	 read -r COUNTRY
	 echo "${LATITUDE},${LONGITUDE},${CITY},${COUNTRY}" | tr --delete \" > done

