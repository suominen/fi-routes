#!/usr/bin/bmake
#
# 20190130  Kimmo Suominen
#

.PHONY: default
default: all

COUNTRY_LIST	=  fi cn
ISP_LIST	!= "${.CURDIR}/isp2asn" LIST

DESTDIR		=  /etc/firewall/routes

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

install: ${DESTDIR}/routes-${i}-inet

${DESTDIR}/routes-${i}-inet: routes-${i}-inet
	install -m 0640 ${.ALLSRC} ${DESTDIR}

install: ${DESTDIR}/routes-${i}-inet6

${DESTDIR}/routes-${i}-inet6: routes-${i}-inet6
	install -m 0640 ${.ALLSRC} ${DESTDIR}
.endfor

summary: routes-summary

.PHONY: routes-summary
routes-summary:
	@for type in inet inet6 ; \
	do \
	    echo ; \
	    wc -l routes-*-"$${type}" \
	    | sort -nr ; \
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

.PHONY: clean
clean:
	rm -f \
	    country-*-asn \
	    country-*-inet \
	    country-*-inet6 \
	    routes-*-inet \
	    routes-*-inet6 \

.PHONY: cleanjson
cleanjson:
	rm -f \
	    country-*.country.json \
	    routes-*.routes.json \

.PHONY: refresh
refresh: cleanjson all

.PHONY: list-targets
list-targets:
	@echo ${.ALLTARGETS} | tr ' ' '\n'
