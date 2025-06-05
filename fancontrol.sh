#!/bin/bash

COMMUNITY="Your iBMC COMMUNITY value"
IBMC_IP="Your iBMC IP address"

#SNMP get CPU Temperature, and support 2 phy CPUs.
#The SNMP return value neet to 1/10 is the Celsius.
CPU1_TEMP_RAW="$(snmpget -v2c -Oq -Ov -c $COMMUNITY $IBMC_IP iso.3.6.1.4.1.2011.2.235.1.1.26.50.1.3.2)"
CPU2_TEMP_RAW="$(snmpget -v2c -Oq -Ov -c $COMMUNITY $IBMC_IP iso.3.6.1.4.1.2011.2.235.1.1.26.50.1.3.3)"
CPU1_TEMP=$(echo "scale=0; $CPU1_TEMP_RAW / 10" | bc)
CPU2_TEMP=$(echo "scale=0; $CPU2_TEMP_RAW / 10" | bc)
if (( $(echo "$CPU1_TEMP >= $CPU2_TEMP" | bc -l) )); then
    CPU_TEMP=$CPU1_TEMP
else
    CPU_TEMP=$CPU2_TEMP
fi

CURRENT_SPEED="$(snmpget -Oq -Ov -v2c -c $COMMUNITY $IBMC_IP .1.3.6.1.4.1.2011.2.235.1.1.8.2.0)"
CURRENT_MODE="$(snmpget -Oq -Ov -v2c -c $COMMUNITY $IBMC_IP .1.3.6.1.4.1.2011.2.235.1.1.8.1.0 | awk -F'[^0-9]+' '{ print $2 }')"

set_auto_mode() {
  if [[ $CURRENT_MODE = 1 ]]; then
    echo "Setting auto mode..."
    snmpset -v2c -c $COMMUNITY $IBMC_IP .1.3.6.1.4.1.2011.2.235.1.1.8.1.0 s "0" > /dev/null
  fi
}

set_manual_mode() {
  if [[ $CURRENT_MODE = 0 ]]; then
    echo "Setting manual mode..."
    snmpset -v2c -c $COMMUNITY $IBMC_IP .1.3.6.1.4.1.2011.2.235.1.1.8.1.0 s "1,0" > /dev/null
  fi

  if [[ $CURRENT_SPEED != $1 ]]; then
    echo "Fan adjusting at $1%."
    snmpset -v2c -c $COMMUNITY $IBMC_IP .1.3.6.1.4.1.2011.2.235.1.1.8.2.0 i $1 > /dev/null
  fi
}

if [[ $CPU_TEMP -gt 70 ]]; then
    set_auto_mode
elif [[ $CPU_TEMP -gt 65 ]]; then
    set_manual_mode 35
elif [[ $CPU_TEMP -gt 55 ]]; then
    set_manual_mode 30
elif [[ $CPU_TEMP -gt 45 ]]; then
    set_manual_mode 25
else
    set_manual_mode 20
fi
