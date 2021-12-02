LATEXRUN ?= ./latexrun

#FIGURES=figures/microbench-speedup-vs-exec.pdf figures/microbench-exec.pdf figures/microbench-boot.pdf figures/microbench-e2e.pdf figures/microbench-role-storage.pdf figures/throughput_simulation.pdf

FIGURES=figures/arch-abstract-graph.pdf figures/arch-system.pdf figures/arch-controller.pdf

all: paper.pdf

.PHONY: FORCE
#paper.pdf: FORCE $(FIGURES)
paper.pdf: FORCE $(FIGURES)
	$(LATEXRUN) --latex-args="-shell-escape" -Wall paper.tex

figures/%.pdf: figures/%.svg
	rsvg-convert -f pdf -o $@ $<

.PHONY: osx
osx:
	open paper.pdf

.PHONY: evince
evince:
	evince paper.pdf

#figures/%.pdf: eval/%.csv eval/plot_bar.py
#	python3 eval/plot_bar.py $< $@
#figures/throughput_simulation.pdf: eval/plot_throughout_simulation.py
#	python3 $^ $@

#figures/microbench-speedup-vs-exec.pdf: eval/optimal.csv eval/snap-reg.csv eval/full-reg.csv
#	cd eval && python3 curve_fitter.py

#figures/microbench-role-storage.pdf: eval/microbench-role-storage.csv eval/snap-reg.csv eval/full-reg.csv
#	cd eval && python3 plot_2bar.py

#.PHONY: gen_fig
#gen_fig:
#	cd eval && \
#	python3 plot_bar.py microbench-boot.csv && \
#	python3 plot_bar.py microbench-exec.csv && \
#	python3 plot_bar.py microbench-e2e.csv && \
#	python3 plot_2bar.py

.PHONY: clean
clean:
	$(LATEXRUN) --clean-all
	#rm -f $(FIGURES)
