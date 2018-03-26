#!/bin/bash

#
# Author: Marcel Boogert
# Source: https://github.com/mboogert/nrpe/blob/master/ssl_check.sh
#

usage() {
    if [ -n "$1" ] ; then
        echo "Error: $1" 1>&2
    fi

    echo
    echo "Usage: protam_ssl_check -D ssldomain [OPTIONS]"
    echo
    echo "Arguments:"
    echo "   -D,--domain domain"
    echo
    echo "Options:"
    echo "   -P,--port              define tcp port to connect to, default is 443"
    echo
    echo "Report bugs to: Marcel Boogert <mboogert@proserve.nl>"
    echo

    exit 3
}

critical() {
    printf 'CRITICAL: %s\n' "$1"
}

warning() {
    printf 'WARN: %s\n' "$1"
}

unknown() {
    printf 'UNKNOWN: %s\n' "$1"
}

test_ssl_certificate_validity() {
    NOT_AFTER=$(echo | timeout 3 openssl s_client -connect $DOMAIN:$PORT -servername $DOMAIN 2>&1 | openssl x509 -noout -dates 2>&1 | grep notAfter | sed 's/notAfter=//' 2>&1) ; NOT_AFTER_EPOCH=$(date --date "$NOT_AFTER" +%s) ; NOW=$(date +%s) ; EXPIRE_IN=$(echo $(((NOT_AFTER_EPOCH-NOW)/86400))) ; echo "$EXPIRE_IN"
    exit 0
}

fetch_ssl_chain () {
  SSL_OUTPUT="`echo | timeout 3 openssl s_client -connect $DOMAIN:$PORT -servername $DOMAIN 2>&1 | sed -n -e '/Certificate chain/,$p' 2>&1 | sed '/---/q' 2>&1 | tail -n +2 | head -n -1`"
  return 0
}

test_sslv3() {
    echo | timeout 3 openssl s_client -connect $DOMAIN:$PORT -servername $DOMAIN -ssl3 2>&1 && SSLV3=1 || SSLV3=0
    echo $SSLV3
}

test_ssl_chain () {
    COUNTER=0
    printf '%s\n' "$SSL_OUTPUT" | while IFS= read -r line
    do

      SUBJECT="$(echo "$line" | grep " s:" | sed 's/^.*CN=//')"
      ISSUER="$(echo "$line" | grep " i:" | sed 's/^.*CN=//')"

      if [ "$ISSUER" == "" ] && [ $COUNTER -gt 1 ]
      then
        if [ "$ISSUER_PREVIOUS" != "$SUBJECT" ]
        then
          printf "position $COUNTER => subject '$SUBJECT' doesn't match issuer '$ISSUER_PREVIOUS'"
          exit 2
        fi
      else
        SUBJECT_PREVIOUS=$SUBJECT
        ISSUER_PREVIOUS=$ISSUER
        COUNTER=$[$COUNTER +1]
        continue
      fi
    
      if [ "$SUBJECT" == "" ] && [ $COUNTER -gt 1 ]
      then
        if [ "$ISSUER_PREVIOUS" != "$SUBJECT" ]
        then
          printf "position $COUNTER => subject '$SUBJECT' doesn't match issuer '$ISSUER_PREVIOUS'"
          exit 2
        fi
      fi
 
      SUBJECT_PREVIOUS=$SUBJECT
      ISSUER_PREVIOUS=$ISSUER
      COUNTER=$[$COUNTER +1]
    done
}

main () {

    PORT=443
    SCORE=0

    while true; do

        case "$1" in

            -h|--help|-\?)
              usage
              exit 0
              ;;

            -D|--domain)
              if [ $# -gt 1 ]; then
                DOMAIN=$2; shift 2
              else
                unknown "-D,--domain requires an argument"
              fi
              ;;

            -P|--port)
              if [ $# -gt 1 ]; then
                PORT=$2; shift 2
              else 
                unknown "-P,--port requires an argument"
              fi
              ;;

            --)
              shift;
              break
              ;;
            -*)
              unknown "invalid option: $1"
              ;;
            *)
              break
              ;;
        
        esac

    done

    if [ -z "${DOMAIN}" ] ; then
        usage "No ssl domain specified"
    fi

    # Test if domain resolves to an ip
    if ! host ${DOMAIN} > /dev/null
    then
      # Retry after 10 seconds
      sleep 10
      if ! host ${DOMAIN} > /dev/null
      then
        echo "UNKNOWN: host ${DOMAIN} cannot be resolved"
        exit 3
      fi
    fi

    # Check SSL chain
    fetch_ssl_chain
    TEST_SSL_CHAIN_OUTPUT="$(test_ssl_chain)"

    case $? in
      0)
        TEST_SSL_CHAIN_ISSUER=$(echo | openssl s_client -connect $DOMAIN:443 -servername $DOMAIN 2>&1 | sed -n -e '/Certificate chain/,$p' 2>&1 | sed '/---/q' 2>&1 | tail -n +2 | head -n -1 | grep -A1 -e '^ 0' | grep -e '^   i:' | sed 's/^.*CN=//')
        TEST_SSL_CHAIN_RETURN="OK: SSL chain is in the correct order (Issuer: $TEST_SSL_CHAIN_ISSUER)"
        TEST_SSL_CHAIN_RETURN_CODE=0
        SCORE=$[$SCORE +0]

        ;;
      1)
        TEST_SSL_CHAIN_RETURN="WARNING: SSL chain warning"
        TEST_SSL_CHAIN_RETURN_CODE=1
        SCORE=$[$SCORE +1]
        ;;
      2)
        TEST_SSL_CHAIN_RETURN="CRITICAL: SSL chain is in the wrong order => $TEST_SSL_CHAIN_OUTPUT"
        TEST_SSL_CHAIN_RETURN_CODE=2
        SCORE=$[$SCORE +2]
        ;;
      *)
        TEST_SSL_CHAIN_RETURN="UNKOWN: SSL chain unknown"
        TEST_SSL_CHAIN_RETURN_CODE=3
        ;;
    esac

    # Test SSL certificate validity
    TEST_SSL_CERTIFICATE_VALIDITY=$(test_ssl_certificate_validity)
    if [ $TEST_SSL_CERTIFICATE_VALIDITY -lt 10 ]
    then
        TEST_SSL_CERTIFICATE_VALIDITY_RETURN="CRITICAL: SSL certificate expires in $TEST_SSL_CERTIFICATE_VALIDITY days"
        TEST_SSL_CERTIFICATE_VALIDITY_RETURN_CODE=2
        SCORE=$[$SCORE +2]
    elif [ $TEST_SSL_CERTIFICATE_VALIDITY -lt 20 ]
    then
        TEST_SSL_CERTIFICATE_VALIDITY_RETURN="WARNING: SSL certificate expires in $TEST_SSL_CERTIFICATE_VALIDITY days"
        TEST_SSL_CERTIFICATE_VALIDITY_RETURN_CODE=1
        SCORE=$[$SCORE +1]
    elif [ $TEST_SSL_CERTIFICATE_VALIDITY -gt 19 ]
    then
        TEST_SSL_CERTIFICATE_VALIDITY_RETURN="OK: SSL certificate expires in $TEST_SSL_CERTIFICATE_VALIDITY days"
        TEST_SSL_CERTIFICATE_VALIDITY_RETURN_CODE=0
    fi

    # Test whether SSLv3 is enabled or not
    TEST_SSLV3_OUTPUT=$(test_sslv3)
    case $? in
      0)
        TEST_SSLV3_RETURN="OK: SSLv3 is disabled"
        TEST_SSLV3_RETURN_CODE=0
        ;;
      1)
        TEST_SSLV3_RETURN="CRITICAL: SSLv3 is enabled"
        TEST_SSLV3_RETURN_CODE=2
        SCORE=$[$SCORE +2]
        ;;
      *)
        TEST_SSLV3_RETURN="UNKOWN: SSLv3 status unknown"
        TEST_SSLV3_RETURN_CODE=3
        ;;
    esac

    if [ $SCORE -eq 0 ]
    then
      echo $TEST_SSL_CHAIN_RETURN
      echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
      echo $TEST_SSLV3_RETURN
    elif [ $SCORE -eq 1 ]
    then
      if [ $TEST_SSL_CHAIN_RETURN_CODE -gt 0 ]
      then
        echo $TEST_SSL_CHAIN_RETURN
        echo ""
        echo "$SSL_OUTPUT"
        echo ""
        echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
        echo $TEST_SSLV3_RETURN
      elif [ $TEST_SSL_CERTIFICATE_VALIDITY_RETURN_CODE -gt 0 ]
      then
        echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
        echo $TEST_SSLV3_RETURN
        echo $TEST_SSL_CHAIN_RETURN
      elif [ $TEST_SSLV3_RETURN_CODE -gt 0 ]
      then
        echo $TEST_SSLV3_RETURN
        echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
        echo $TEST_SSL_CHAIN_RETURN
      fi
      exit 1
    elif [ $SCORE -gt 1 ]
    then
      if [ $TEST_SSL_CHAIN_RETURN_CODE -gt 0 ]
      then
        echo $TEST_SSL_CHAIN_RETURN
        echo ""
        echo "$SSL_OUTPUT"
        echo ""
        echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
        echo $TEST_SSLV3_RETURN
      elif [ $TEST_SSL_CERTIFICATE_VALIDITY_RETURN_CODE -gt 0 ]
      then
        echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
        echo $TEST_SSLV3_RETURN
        echo $TEST_SSL_CHAIN_RETURN
      elif [ $TEST_SSLV3_RETURN_CODE -gt 0 ]
      then
        echo $TEST_SSLV3_RETURN
        echo $TEST_SSL_CERTIFICATE_VALIDITY_RETURN
        echo $TEST_SSL_CHAIN_RETURN
      fi
      exit 2
    fi

}

main "${@}"
