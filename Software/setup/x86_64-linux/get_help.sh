#!/bin/bash
echo "Downloading Wiki Pages\n"
../../../../../Source/wikihelp/output/i386-linux/wikidownload --allpages="http://wiki.ullihome.de/index.php/Spezial:Alle_Seiten" --exportpage="http://wiki.ullihome.de/index.php/Spezial:Exportieren" --pageoffset="USBAVR-ISP-Firmwares" --output="../../help"
echo "Converting Wiki Pages\n"
../../../../../Source/wikihelp/output/i386-linux/wiki2html "../../help"

