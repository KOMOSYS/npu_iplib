all:
	cd sim; \
	make clean; make sim SIM_TYPE=RTL_SIM; \
	make mrg_cov; make rpt_cov; \
	cd ../syn; \
	make clean; make all; \
	cd ../sim; \
	make clean; make sim SIM_TYPE=PRE_SIM; \
	cd ../pwr; \
	make clean; make all; \
	cd ..; \
	python3 ../../script/summary/make_md.py -u sim/urgReport -a syn -p pwr;