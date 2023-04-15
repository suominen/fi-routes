#!/usr/bin/bmake
#
# 20190130  Kimmo Suominen
#

.PHONY: default
default: all

COUNTRY_LIST	=  fi cn ru
ISP_LIST	!= "${.CURDIR}/isp2asn" LIST
GCP_REGIONS	=  us-east1 europe-north1

DESTDIR		=  /etc/firewall
ROUTES		=  routes
NETWORKS	=  networks

.SUFFIXES: -asn -inet -inet6 .country.json .routes.json

.PHONY: all install summary

summary: isp-summary

.PHONY: isp-summary
isp-summary:
	@"${.CURDIR}/isp2asn" SUMMARY

.for i in ${COUNTRY_LIST}
all: country-${i}-asn country-${i}-inet country-${i}-inet6

country-${i}.country.json:
	curl -LSs "$$( \
	    echo \
		https://stat.ripe.net/data/ \
		country-resource-list \
		/data.json?resource= \
		$$( \
		    echo "${i}" \
		    | tr '[:lower:]' '[:upper:]' \
		) \
	    | tr -d '[:space:]' \
	)" > "${.TARGET}"

summary: country-${i}-summary

country-${i}-summary:
	@echo
	@wc -l country-"${i}"-asn
	@echo
	@wc -l country-"${i}"-inet* | sort -nr
.endfor

.for i in ${ISP_LIST}
all: routes-${i}-inet routes-${i}-inet6

routes-${i}.routes.json:
	curl -LSs "$$( \
	    echo \
		https://stat.ripe.net/data/ \
		announced-prefixes \
		/data.json?resource= \
		$$(${.CURDIR}/isp2asn "${i}") \
	    | tr -d '[:space:]' \
	)" > "${.TARGET}"

install: ${DESTDIR}/${ROUTES}/routes-${i}-inet

${DESTDIR}/${ROUTES}/routes-${i}-inet: routes-${i}-inet
	install -m 0640 ${.ALLSRC} ${.TARGET}

install: ${DESTDIR}/${ROUTES}/routes-${i}-inet6

${DESTDIR}/${ROUTES}/routes-${i}-inet6: routes-${i}-inet6
	install -m 0640 ${.ALLSRC} ${.TARGET}
.endfor

summary: network-routes-summary

.PHONY: network-routes-summary
network-routes-summary:
	@for type in network routes ; \
	do \
	    for family in inet inet6 ; \
	    do \
		echo ; \
		wc -l "$${type}"-*-"$${family}" \
		| sort -nr ; \
	    done ; \
	done

.country.json-asn:
	jq -r '.data.resources.asn[]' \
	< "${.ALLSRC}" \
	> "${.TARGET}"

.country.json-inet:
	jq -r '.data.resources.ipv4[]' \
	< "${.ALLSRC}" \
	| while read line ; \
	do \
	    case "$${line}" in \
	    *-*) \
		ipcalc "$${line}" \
		| sed -n '1n;p' \
		;; \
	    *) \
		echo "$${line}" \
		;; \
	    esac \
	done \
	| "${.CURDIR}/cidr.py" \
	> "${.TARGET}"

.country.json-inet6:
	jq -r '.data.resources.ipv6[]' \
	< "${.ALLSRC}" \
	| "${.CURDIR}/cidr.py" \
	> "${.TARGET}"

.routes.json-inet:
	jq -r '.data.prefixes[].prefix' \
	< "${.ALLSRC}" \
	| fgrep -v ':' \
	| "${.CURDIR}/cidr.py" \
	> "${.TARGET}"

.routes.json-inet6:
	jq -r '.data.prefixes[].prefix' \
	< "${.ALLSRC}" \
	| fgrep ':' \
	| "${.CURDIR}/cidr.py" \
	> "${.TARGET}"

# Obtain Google IP address ranges
# https://support.google.com/a/answer/10026322

#google-all.json:
#	curl -LSs https://www.gstatic.com/ipranges/goog.json > "${.TARGET}"

google-cloud.json:
	curl -LSs https://www.gstatic.com/ipranges/cloud.json > "${.TARGET}"

.for i in ${GCP_REGIONS}
all: network-gcp-${i}-inet

network-gcp-${i}-inet: google-cloud.json
	jq -r --arg region "${i}" '.prefixes[] | select(.scope == $$region) \
	    | select(.ipv4Prefix != null) | .ipv4Prefix' "${.ALLSRC}" \
	> "${.TARGET}"

all: network-gcp-${i}-inet6

network-gcp-${i}-inet6: google-cloud.json
	jq -r --arg region "${i}" '.prefixes[] | select(.scope == $$region) \
	    | select(.ipv6Prefix != null) | .ipv6Prefix' "${.ALLSRC}" \
	> "${.TARGET}"

#install: ${DESTDIR}/${NETWORKS}/network-gcp-${i}-inet

#${DESTDIR}/${NETWORKS}/network-gcp-${i}-inet: network-gcp-${i}-inet
#	install -m 0640 ${.ALLSRC} ${.TARGET}

#install: ${DESTDIR}/${NETWORKS}/network-gcp-${i}-inet6

#${DESTDIR}/${NETWORKS}/network-gcp-${i}-inet6: network-gcp-${i}-inet6
#	install -m 0640 ${.ALLSRC} ${.TARGET}
.endfor

.PHONY: clean
clean:
	rm -f \
	    country-*-asn \
	    country-*-inet \
	    country-*-inet6 \
	    network-gcp-*-inet \
	    network-gcp-*-inet6 \
	    routes-*-inet \
	    routes-*-inet6 \

.PHONY: cleanjson
cleanjson:
	rm -f \
	    country-*.country.json \
	    google-cloud.json \
	    routes-*.routes.json \

.PHONY: refresh
refresh: cleanjson all

.PHONY: list-targets
list-targets:
	@echo ${.ALLTARGETS} | tr ' ' '\n'
