THISDIR = $(shell pwd)

all:

clean:

romfs:
	$(ROMFSINST) -p +x $(THISDIR)/routeflow.sh /usr/bin/routeflow.sh
	$(ROMFSINST) -d $(THISDIR)/gfwlist.txt /etc_ro/routeflow/gfwlist.txt
