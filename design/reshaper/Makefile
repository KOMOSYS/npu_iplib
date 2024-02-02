all:
	cd syn; \
	make clean; make all; \
	cd ../sim; \
	make clean; make sim SIM_TYPE=PRE_SIM; \
	cd ../pwr; \
	make clean; make all; \
	cd ..
