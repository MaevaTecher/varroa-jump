## Population genetic analysis of Varroa on native and introduced hosts
from scripts.split_fasta_regions import split_fasta
from snakemake.utils import R

## Set path for input files and fasta reference genome
outDir = "/work/MikheyevU/Maeva/varroa-jump/data"
refDir = "/work/MikheyevU/Maeva/varroa-jump/ref" 
SCRATCH  = "/work/scratch/maeva"

## Honey bee references from Apis mellifera & Apis cerana
hostBeeBowtieIndex = refDir + "/bees/hostbee"
hostBeeMtBowtieIndex = refDir + "/bees/mtdna"
hostBowtiemellifera = refDir + "/bees/mellifera"
hostBowtiecerana = refDir + "/bees/cerana"
ceranamt = refDir + "/bees/mtdnabee/ceranamtDNA"
melliferamt = refDir + "/bees/mtdnabee/melliferamtDNA"
floreamt = refDir + "/bees/mtdnabee/floreamtDNA"

## Varroa destructor and V. jacobosni references
varroaBowtieIndex = refDir + "/destructor/vd"
vdRef = refDir + "/destructor/vd.fasta"
vjRef = refDir + "/jacobsoni/vj.fasta"
vdmtDNABowtieIndex = refDir + "/destructor/mtdnamite/vdnavajas"
vdmtDNA = refDir + "/destructor/mtdnamite/VDAJ493124.fasta"
CHROMOSOMES = ["BEIS01000001.1", "BEIS01000002.1", "BEIS01000003.1", "BEIS01000004.1", "BEIS01000005.1", "BEIS01000006.1", "BEIS01000007.1"] 
LOCI = ["BEIS01000001.1:603001-613000", "BEIS01000001.1:1390001-1400000", "BEIS01000002.1:441001-451000", "BEIS01000002.1:9105001-9115000", "BEIS01000003.1:11339001-11349000", "BEIS01000003.1:39994001-40004000", "BEIS01000004.1:7757001-7767000", "BEIS01000004.1:40865001-40875000", "BEIS01000005.1:4225001-4235000", "BEIS01000005.1:26318001-26328000", "BEIS01000006.1:9351001-9361000", "BEIS01000006.1:13682001-13692000", "BEIS01000007.1:5832001-5842000", "BEIS01000007.1:26629001-26639000"]

krakenDB = "/work/MikheyevU/kraken_db"

## Input fastq.gz files generated by whole genome sequencing from 44 individuals
SAMPLES, = glob_wildcards(outDir + "/reads/{sample}-R1_001.fastq.gz")

## Creation of parameters for splitting reference genome and cut off computation time
SPLITS = range(200)
REGIONS = split_fasta(vdRef, len(SPLITS))  # dictionary with regions to be called, with keys in SPLITS
Q = (20, 40) # 99 and 99.99% mapping accuracy
for region in REGIONS:
	for idx,i in enumerate(REGIONS[region]):
		REGIONS[region][idx] = " -r " + str(i)

SPLITSMT = range(10)
REGIONSMT = split_fasta(vdmtDNA, len(SPLITSMT))  # dictionary with regions to be called, with keys in SPLITS
Q = (20, 40) # 99 and 99.99% mapping accuracy
for regionmt in REGIONSMT:
        for idx,i in enumerate(REGIONSMT[regionmt]):
                REGIONSMT[regionmt][idx] = " -r " + str(i)


## Pseudo rule for build-target
rule all:
	input: 	expand(outDir + "/alignments-new/ngm/{sample}.bam", sample = SAMPLES), 
		expand(outDir + "/alignments-new/ngm/{sample}.bam.bai", sample = SAMPLES)
		
##---- PART1 ---- Check the host identity by mapping reads on honey bee reference genome
## Use only mitochondrial DNA to verify host identity
rule checkHost:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz",
	output:
		temp(outDir + "/meta/hosts/{sample}-{q}.txt")
	threads: 12
	shell:
		"""
		module load bowtie2/2.2.6 samtools/1.3.1
		bowtie2 -p {threads} -x {hostBeeMtBowtieIndex} -1  {input.read1} -2 {input.read2} | samtools view -S -q {wildcards.q}  -F4 - | awk -v mellifera=0 -v cerana=0 -v sample={wildcards.sample} '$3~/^L/ {{mellifera++; next}}  {{cerana++}} END {{if(mellifera>cerana) print sample"\\tmellifera\\t"cerana"\\t"mellifera ; else print sample"\\tcerana\\t"cerana"\\t"mellifera}}' > {output}
		"""

rule combineHost:
	input:
		expand(outDir + "/meta/hosts/{sample}-{{q}}.txt", sample = SAMPLES)
	output:
		outDir + "/meta/hosts/hosts-{q}.txt"
	shell:
		"""
		(echo -ne "id\\thost\\tcerana\\tmellifera\\n"; cat {input}) > {output}
		"""

rule removeHost:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz",
	threads: 12
	output: temp(outDir + "/sketches/{sample}.fastq.gz")
	shell: 
		"""
		module load bowtie2/2.2.6 samtools/1.3.1
		bowtie2 -p {threads} -x {hostBeeBowtieIndex} -1  {input.read1} -2 {input.read2}  | samtools view -S -f12 | awk '{{print "@"$1"\\n"$10"\\n+\\n"$11}}' | gzip > {output}
		"""
		
# Use mtDNA to verify host identity
rule checkmellifera:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz"
	output: alignment = temp(outDir + "/hostbee/mellifera/{sample}.bam"),
		index = temp(outDir + "/hostbee/mellifera/{sample}.bam.bai")
	shell: 
		"""
		bowtie2 -p {threads} --very-sensitive-local --sam-rg ID:{wildcards.sample} --sam-rg LB:Nextera --sam-rg SM:{wildcards.sample} --sam-rg PL:ILLUMINA -x {melliferamt} -1 {input.read1} -2 {input.read2} | samtools view -Su -q20 -F4 - | samtools sort - -m 55G -T {SCRATCH}/bowtie/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
		samtools index {output.alignment}
	    	"""
		
rule checkcerana:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz"
	output: alignment = temp(outDir + "/hostbee/cerana/{sample}.bam"),
                index = temp(outDir + "/hostbee/cerana/{sample}.bam.bai")
	shell: 
		"""
		bowtie2 -p {threads} --very-sensitive-local --sam-rg ID:{wildcards.sample} --sam-rg LB:Nextera --sam-rg SM:{wildcards.sample} --sam-rg PL:ILLUMINA -x {ceranamt} -1 {input.read1} -2 {input.read2} | samtools view -Su -F4 - | samtools sort - -m 55G -T {SCRATCH}/bowtie/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
                samtools index {output.alignment}
               	"""

rule checkflorea:
        input:
                read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
                read2 = outDir + "/reads/{sample}-R2_001.fastq.gz"
        output: alignment = temp(outDir + "/hostbee/florea/{sample}.bam"),
                index = temp(outDir + "/hostbee/florea/{sample}.bam.bai")
        shell: 
		"""
		bowtie2 -p {threads} --very-sensitive-local --sam-rg ID:{wildcards.sample} --sam-rg LB:Nextera --sam-rg SM:{wildcards.sample} --sam-rg PL:ILLUMINA -x {floreamt} -1 {input.read1} -2 {input.read2} | samtools view -Su -F4 - | samtools sort - -m 55G -T {SCRATCH}/bowtie/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
                samtools index {output.alignment}
               	"""

##---- PART2 ---- Exploratory analysis on reads that only mapped on Varroa genomes + variant calling

rule mashtree:
	input: expand(outDir + "/sketches/{sample}.fastq.gz", sample = SAMPLES)
	output: tree = outDir + "/sketches/varroa.dnd", matrix = outDir + "/sketches/varroa.phylip"
	threads: 12
	shell: "mashtree.pl --genomesize 500000000 --mindepth 2 --tempdir /work/MikheyevU/Maeva/varroahost/scratch --numcpus {threads} --outmatrix {output.matrix} {input} > {output.tree}"

## Here reads will be mapped using either bowtie2 or ngm, then test which one is the best
## on whole genome
rule bowtie2:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz",
	threads: 12
	output: 
		alignment = temp(outDir + "/alignments-new/bowtie2/{sample}.bam"), 
		index = temp(outDir + "/alignments-new/bowtie2/{sample}.bam.bai"),
		read1 = outDir + "/reads_unmapped_new/{sample}.1",
		read2 = outDir + "/reads_unmapped_new/{sample}.2"

	shell:
		"""
		module load bowtie2/2.2.6 samtools/1.3.1 VariantBam/1.4.3
		bowtie2 -p {threads} --very-sensitive-local --sam-rg ID:{wildcards.sample} --sam-rg LB:Nextera --sam-rg SM:{wildcards.sample} --sam-rg PL:ILLUMINA  --un-conc-gz  {outDir}/reads_unmapped_new/{wildcards.sample} -x {varroaBowtieIndex} -1 {input.read1} -2 {input.read2} | samtools view -Su - | samtools sort - -m 55G -T {SCRATCH}/bowtie/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
		samtools index {output.alignment}
		"""

rule kraken:
	input: outDir + "/reads_unmapped/{sample}.1.fastq.gz", outDir + "/reads_unmapped/{sample}.2.fastq.gz"
	output: outDir + "/kraken/{sample}.txt"
	threads: 12
	shell:
		"""
		module load Kraken/1.0 jellyfish/1.1.11
		kraken --preload --db {krakenDB} --gzip-compressed --threads {threads} --paired --output {output} --fastq-input {input}
		"""

rule krakenMerge:
	input: expand(outDir + "/kraken/{sample}.txt", sample = SAMPLES)
	output: outDir + "/R/microbes.csv.gz"
	shell:
		"""
		( echo "id,taxId,count" 
 		for i in {input}; do
			awk '$3!=0 {{print $3}}' $i | sort | uniq -c | awk -v OFS="," -v species=$(basename $i .txt) '{{print species, $2, $1}}' 
		done ) | gzip > {output}
		"""

rule nextgenmap:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz",
	threads: 12
	output: 
		alignment = temp(outDir + "/alignments-new/ngm/{sample}.bam"), 
		index = temp(outDir + "/alignments-new/ngm/{sample}.bam.bai")
	shell:
		"""
		module load NextGenMap/0.5.0 samtools/1.3.1 VariantBam/1.4.3
		ngm -t {threads} -b  -1 {input.read1} -2 {input.read2} -r {vdRef} --rg-id {wildcards.sample} --rg-sm {wildcards.sample} --rg-pl ILLUMINA --rg-lb {wildcards.sample} | samtools sort - -m 80G -T {SCRATCH}/ngm/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
		samtools index {output.alignment}
		"""
rule ngmVJ:
	input:
		read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
		read2 = outDir + "/reads/{sample}-R2_001.fastq.gz",
	threads: 12
	output: 
		alignment = temp(outDir + "/alignments-new/ngm_vj/{sample}.bam"), 
		index = temp(outDir + "/alignments-new/ngm_vj/{sample}.bam.bai")
	shell:
		"""
		module load NextGenMap/0.5.0 samtools/1.3.1 VariantBam/1.4.3
		ngm -t {threads} -b  -1 {input.read1} -2 {input.read2} -r {vjRef} --rg-id {wildcards.sample} --rg-sm {wildcards.sample} --rg-pl ILLUMINA --rg-lb {wildcards.sample} | samtools sort - -m 80G -T {SCRATCH}/ngm_vj/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
		samtools index {output.alignment}
		"""
		
rule freeBayes:
	input: 
		expand(outDir + "/alignments-new/{{aligner}}/{sample}.bam", sample = SAMPLES)
	output: 
		temp(outDir + "/var/{aligner}/split/freebayes.{region}.vcf")
	params: 
		span = lambda wildcards: REGIONS[wildcards.region],
		bams = lambda wildcards, input: os.path.dirname(input[0]) + "/*.bam",
		missing = lambda wildcards, input: len(input) * 0.9
	shell:
		"""
		module load freebayes/1.1.0 vcftools/0.1.12b vcflib/1.0.0-rc1
		for i in {params.bams}; do name=$(basename $i .bam); if [[ $name == VJ* ]] ; then echo $name VJ; else echo $name VD; fi ; done > {outDir}/var/pops.txt
		freebayes --min-alternate-fraction 0.2 --use-best-n-alleles 4 -m 5 -q 5 --populations {outDir}/var/pops.txt -b {params.bams} {params.span}  -f {vdRef} | vcffilter  -f "QUAL > 20 & NS > {params.missing}" > {output}
		"""

rule mergeVCF:
	input: 
		expand(outDir + "/var/{{aligner}}/split/freebayes.{region}.vcf", region = REGIONS)
	output:
		temp(outDir + "/var/{aligner}/raw.vcf")
	shell:
		"""
		module load vcflib/1.0.0-rc1
		(grep "^#" {input[0]} ; cat {input} | grep -v "^#" ) | vcfuniq  > {output}
		"""

rule filterVCF:
	# see http://ddocent.com//filtering/
	# filter DP  + 3*sqrt(DP) https://arxiv.org/pdf/1404.0929.pdf
	# also sites with more than two variants
	input:
		rules.mergeVCF.output
	output:
		vcf = outDir + "/var/{aligner}/filtered.vcf"
	shell:
		"""
		module load vcftools/0.1.12b vcflib/1.0.0-rc1 eplot/2.08
		perl  -ne 'print "$1\\n" if /DP=(\d+)/'  {input} > {outDir}/var/{wildcards.aligner}/depth.txt
		sort -n {outDir}/var/{wildcards.aligner}/depth.txt | uniq -c | awk '{{print $2,$1}}' | eplot -d -r [200:2000] 2>/dev/null | tee 
		Nind=$(grep -m1 "^#C" {input}  | cut -f10- |wc -w)
		coverageCutoff=$(awk -v Nind=$Nind '{{sum+=$1}} END {{print "DP < "(sum / NR / Nind + sqrt(sum / NR / Nind) * 3 ) * Nind}}' {outDir}/var/{wildcards.aligner}/depth.txt)
		echo Using coverage cutoff $coverageCutoff
		vcffilter -s -f \"$coverageCutoff\" {input} | vcftools --vcf - --exclude-bed ref/destructor/masking_coordinates --max-alleles 2 --recode --stdout > {output}
		"""

rule chooseMapper:
	# The results are very similar between the two mappers, so we're going with the one that has the greatest number of variants
	input:
		ngm = outDir + "/var/ngm/filtered.vcf", 
		bowtie2 = outDir + "/var/bowtie2/filtered.vcf", 
	output:
		bgzip = outDir + "/var/filtered.vcf.gz",
		primitives = outDir + "/var/primitives.vcf.gz"
	shell:
		"""
		module load samtools/1.3.1 vcflib/1.0.0-rc1
		ngm=$(grep -vc "^#" {input.ngm})
		bowtie2=$(grep -vc "^#" {input.bowtie2})
		echo ngm has $ngm snps vs $bowtie2 for bowtie2 
		if [[ $ngm -gt $bowtie2 ]]; then
			echo choosing ngm
			bgzip -c {input.ngm} > {output.bgzip}
			vcftools --vcf {input.ngm} --recode --remove-indels --stdout | vcfallelicprimitives | bgzip > {output.primitives}
		else
			echo choosing bowtie2
			bgzip -c {input.bowtie2} > {output.bgzip}
			vcftools --vcf {input.bowtie2} --recode --remove-indels --stdout | vcfallelicprimitives  | bgzip > {output.primitives}
		fi
		tabix -p vcf {output.bgzip} && tabix -p vcf {output.primitives}
		"""

# At this point we go with ngm, which produces a bit more variants

rule VCF012:
	# convert vcf to R data frame with meta-data 
	# remove maf 0.1, since we don't have much power for them
	input: 
		vcf = outDir + "/var/filtered.vcf.gz",
		ref = refDir + "/varroa.txt"
	output: "data/R/{species}.txt"
	shell: 
		"""
		module load vcftools/0.1.12b
		vcftools --gzvcf {input.vcf} --012 --mac 1 --keep <(awk -v species={wildcards.species} '$3==toupper(species) {{print $1 }}' {input.ref}) --maf 0.1 --out data/R/{wildcards.species}
		# transpose loci to columns
		(echo -ne "id\\thost\\tspecies\\t"; cat data/R/{wildcards.species}.012.pos | tr "\\t" "_" | tr "\\n" "\\t" | sed 's/\\t$//'; echo) > {output}
		# take fedHost and species columns and append them to the genotype data file
		paste <(awk 'NR==FNR {{a[$1]=$1"\\t"$4"\\t"$3; next}} $1 in a {{print a[$1]}}' {input.ref} data/R/{wildcards.species}.012.indv) <(cat data/R/{wildcards.species}.012  | cut -f2-) | sed 's/-1/9/g' >> {output}
		"""

## The vcf file generated by freebayes and filtered by vcftools have too much details in the header which is incompatible with further use for gatk
## Erase all lines in primitives.vcf.gz between ##fileformat=VCFv4.2 up to #CHROM...

##---- PART3 ---- Analysis on whole genome vcf file, finding Fst outliers, population differentiation and structure analysis
#overall distance matrix
rule VCF2Dis:
	input: outDir + "/var/filtered.vcf.gz"
	output: outDir + "/var/filtered.mat"
	shell: "module load VCF2Dis/1.09; VCF2Dis -InPut {input} -OutPut {output}"

rule outflankFst:
	# compute FST for outflank analysis
	input:
		outDir + "/R/{species}.txt"
	output: 
		outDir + "/R/{species}.outflank.rds"
	shell:
		"Rscript --vanilla scripts/outflank.R {input} {output}"

rule popstats:
	input:
		vcf = outDir + "/var/filtered.vcf.gz",
		ref = refDir + "/varroa.txt"
	output:
		dFst = outDir + "/R/dFst.txt", jFst = outDir + "/R/jFst.txt", dcStats =outDir + outDir + "/R/dcStats.txt", dmStats = outDir + "/R/dmStats.txt", jcStats = outDir + "/R/jcStats.txt", jmStats = outDir + "/R/jmStats.txt", dpFst = outDir + "/R/dpFst.txt", jpFst = outDir + "/R/jpFst.txt"
	threads: 8
	resources: mem=20, time=12*60
	shell:
		"""
		module load vcflib/1.0.0-rc1 parallel
		dc=$(awk -v host=cerana -v species=VD -v ORS=, '(NR==FNR) {{a[$1]=NR-1; next}} ($2==host) && ($3==species) {{print a[$1]}}'  <(zcat {input.vcf} |grep -m1 "^#C" | cut -f10- | tr "\\t" "\\n") {input.ref} | sed 's/,$//')
		dm=$(awk -v host=mellifera -v species=VD -v ORS=, '(NR==FNR) {{a[$1]=NR-1; next}} ($2==host) && ($3==species) {{print a[$1]}}'  <(zcat data/var/filtered.vcf.gz |grep -m1 "^#C" | cut -f10- | tr "\\t" "\\n") {input.ref} | sed 's/,$//')
		jm=$(awk -v host=mellifera -v species=VJ -v ORS=, '(NR==FNR) {{a[$1]=NR-1; next}} ($2==host) && ($3==species) {{print a[$1]}}'  <(zcat data/var/filtered.vcf.gz |grep -m1 "^#C" | cut -f10- | tr "\\t" "\\n") {input.ref} | sed 's/,$//')
		jc=$(awk -v host=cerana -v species=VJ -v ORS=, '(NR==FNR) {{a[$1]=NR-1; next}} ($2==host) && ($3==species) {{print a[$1]}}'  <(zcat data/var/filtered.vcf.gz |grep -m1 "^#C" | cut -f10- | tr "\\t" "\\n") {input.ref} | sed 's/,$//')
		#compute Fst for both species

		tempfile=$(mktemp)
		echo "wcFst --target $dm --background $dc --file {input} --type GL  > {output.dFst} " >> $tempfile
		echo "wcFst --target $jm --background $jc --file {input} --type GL  > {output.jFst}" >> $tempfile
		echo "pFst --target $dm --background $dc --file {input} --type GL  > {output.dpFst} " >> $tempfile
		echo "pFst --target $jm --background $jc --file {input} --type GL  > {output.jpFst} " >> $tempfile
		#compute descriptive statistics for both species
		echo "popStats --type GL --target $dc --file {input}  > {output.dcStats}" >> $tempfile
		echo "popStats --type GL --target $dm --file {input}  > {output.dmStats}" >> $tempfile
		echo "popStats --type GL --target $jc --file {input}  > {output.jcStats}" >> $tempfile
		echo "popStats --type GL --target $jm --file {input}  > {output.jmStats}" >> $tempfile
		cat $tempfile | xargs -P {threads} -I % sh -c '%'
		rm $tempfile
		"""

# # estimate SNP effects
# rule snpEff:
# 	input: rules.consensusFilter.output
# 	output: "../data/popgen/var/snpEff.txt"
# 	shell: "java -Xmx7g -jar /apps/unit/MikheyevU/sasha/snpEff4/snpEff.jar -no-utr -no-upstream -no-intron -no-intergenic -no-downstream pmuc {input} >  {output}"
# 	""" python parse_silentReplacement.py ../ref/csd.fa temp.txt > {output} && rm temp.txt """

# rule getCDS:
# 	input: GFF, REF
# 	output: "../ref/cds.fa"
# 	shell: "gffread {input[0]} -g {input[1]} -x {output}"

# rule filterLongest:
# 	input: rules.getCDS.output
# 	output: "../ref/longest.fa"
# 	shell: "python filter_longest.py {input} > {output}"

# # determine which SNPs are fixed and which are polymorphic
# # for this we remove the outgroup and compute frequencies
# rule fixedPolymorphic:	
# 	input: rules.consensusFilter.output
# 	output: "../data/popgen/var/snps.csv"
# 	shell: """module load zlib; vcftools --vcf {input} --remove-indv Pflavoviridis --freq; \
#     awk -v OFS="," ' NR>1 {{split($5,a,":"); if((a[2]=="1") || (a[2]=="0")) state="F"; else state="P"; print $1,$2,state}}' out.frq > {output} """

# # exports silent and replacement sites from snpEff
# rule parseSilentReplacement:
# 	input: rules.filterLongest.output, rules.snpEff.output
# 	output: "../data/popgen/var/annotation.csv"
# 	shell: ". ~/python2/bin/activate ; python parse_silentReplacement.py {input} > {output}"

# # calculate how many synonymous vs_non-synonymous changes are possible
# rule silentReplacement:
# 	input: rules.filterLongest.output
# 	output: "../data/popgen/var/silentReplacement.csv"
# 	shell: ". ~/python2/bin/activate; python silent_replacement.py {input} > {output}"

# rule snipre:
# 	input: rules.silentReplacement.output, rules.fixedPolymorphic.output, rules.parseSilentReplacement.output
# 	output: "../out/bayesian_results.csv"
				
##---- PART4 ---- Getting sequences for mtDNA phylogenies and for demographic inferences
rule mtDNA_ngm:
        input:
                read1 = outDir + "/reads/{sample}-R1_001.fastq.gz",
                read2 = outDir + "/reads/{sample}-R2_001.fastq.gz",
        threads: 12
        output:
                alignment = temp(outDir + "/alignments-new/ngm_mtDNA/{sample}.bam"),
                index = temp(outDir + "/alignments-new/ngm_mtDNA/{sample}.bam.bai")
        shell:
                """
		ngm -t {threads} -b  -1 {input.read1} -2 {input.read2} -r {vdmtDNA} --rg-id {wildcards.sample} --rg-sm {wildcards.sample} --rg-pl ILLUMINA --rg-lb {wildcards.sample} | samtools view -Su -F4 -q10 | samtools sort - -m 55G -T {SCRATCH}/ngm_mtDNA/{wildcards.sample} -o - | samtools rmdup - - | variant - -m 500 -b -o {output.alignment}
                samtools index {output.alignment}
                """

rule mtDNA_freeBayes:
        input:
                expand(outDir + "/alignments-new/ngm_mtDNA/{sample}.bam", sample = SAMPLES)
        output:
                temp(outDir + "/var/ngm_mtDNA/split_mtDNA/freebayes_mtDNA.{regionmt}.vcf")
        params:
                span = lambda wildcards: REGIONSMT[wildcards.regionmt],
                bams = lambda wildcards, input: os.path.dirname(input[0]) + "/*.bam",
                missing = lambda wildcards, input: len(input) * 0.9
        shell:
                """
		 for i in {params.bams}; do name=$(basename $i .bam); if [[ $name == VJ* ]] ; then echo $name VJ; else echo $name VD; fi ; done > {outDir}/var/pops_mtDNA.txt
                freebayes --ploidy 1 --min-alternate-fraction 0.2 --use-best-n-alleles 4 -m 5 -q 5 --populations {outDir}/var/pops_mtDNA.txt -b {params.bams} {params.span} -f {vdmtDNA} | vcffilter -f "QUAL > 20 & NS > {params.missing}" > {output}
                """

rule mtDNA_mergeVCF:
        input:
                expand(outDir + "/var/ngm_mtDNA/split_mtDNA/freebayes_mtDNA.{regionmt}.vcf", regionmt = REGIONSMT)
        output:
                temp(outDir + "/var/ngm_mtDNA/raw_mtDNA.vcf")
        shell:
                """
		(grep "^#" {input[0]} ; cat {input} | grep -v "^#" ) | vcfuniq  > {output}
                """

		
rule mtDNA_filterVCF:
        input:
                rules.mtDNA_mergeVCF.output
        output:
                vcf = outDir + "/var/ngm_mtDNA/filtered_mtDNA.vcf"
        shell:
                """
		perl  -ne 'print "$1\\n" if /DP=(\d+)/'  {input} > {outDir}/var/ngm_mtDNA/depth_mtDNA.txt
                sort -n {outDir}/var/ngm_mtDNA/depth_mtDNA.txt | uniq -c | awk '{{print $2,$1}}' | eplot -d -r [200:2000] 2>/dev/null | tee
                Nind=$(grep -m1 "^#C" {input}  | cut -f10- |wc -w)
                coverageCutoff=$(awk -v Nind=$Nind '{{sum+=$1}} END {{print "DP < "(sum / NR / Nind + sqrt(sum / NR / Nind) * 3 ) * Nind}}' {outDir}/var/ngm_mtDNA/depth_mtDNA.txt)
                echo Using coverage cutoff $coverageCutoff
                vcffilter -s -f \"$coverageCutoff\" {input} | vcftools --vcf - --max-alleles 2 --recode --stdout > {output}
                """
		
###using vcflib
## I used finally only the rawmtDNA.vcf fasta file and checked manually for problem that could appear with gap == alignment good
rule vcf2fasta_mtdna:
		input: outDir + "/var/ngm_mtDNA/raw_mtDNA.vcf"
		output: outDir + "/var/ngm_mtDNA/fasta/{sample}.fasta"
		shell: 
			"""
			vcf2fasta -f {vdmtDNA} -P1 > {output}
			"""

			
##Be careful, GATK version 4.0.0 have a slight different program option than the 3.0 version. As example, FastaAlternateReferenceMaker is not available in 4.0.0.
##using GATK 4.0.0
rule selectVariant:
	input: outDir + "/var/primitives.vcf.gz"
	output: indiv = temp(outDir + "/var/singlevcf/selectvariants/{sample}.vcf"),
		bgzip = temp(outDir + "/var/singlevcf/selectvariants/{sample}.vcf.gz")
	shell: 
		"""
		gatk SelectVariants -R {vdRef} --variant {input} --output {output.indiv} -sn {wildcards.sample}
		bgzip -c {output.indiv} > {output.bgzip}
		tabix -p vcf {output.bgzip}
		"""

rule bcftools_indiv:
	input: outDir + "/var/primitives.vcf.gz"
	output: temp(outDir + "/var/singlevcf/{sample}.vcf.gz")
	shell: 
		"""
		bcftools view -Oz -s {wildcards.sample} {input} > {output}
		tabix -p vcf {output}
		"""

## Cut the big vcf file to load it easily into igv and decide with regions to choose for future IMa2 runs
rule selectVarChrom:
        input: outDir + "/var/primitives.vcf.gz"
        output: chrom = temp(outDir + "/var/chrmvcf/selectvariants/{chromosome}.vcf"),
                bgzip = temp(outDir + "/var/chrmvcf/selectvariants/{chromosome}.vcf.gz")
        shell:
                """
                gatk SelectVariants -R {vdRef} --variant {input} --output {output.chrom} -L {wildcards.chromosome}
                bgzip -c {output.chrom} > {output.bgzip}
                tabix -p vcf {output.bgzip}
		"""
		
rule bcftools_chrom:
        input: outDir + "/var/primitives.vcf.gz"
        output: temp(outDir + "/var/chrmvcf/bcftools/{chromosome}.vcf.gz")
        shell:
                """
                bcftools view -Oz -r {wildcards.chromosome} {input} > {output}
		tabix -p vcf {output}
		"""
		
rule bcftools_Ima2:
	input:
		variant = outDir + "/var/primitives.vcf.gz",
		chosen = outDir + "/ima2/imindiv.txt"
	output: temp(outDir + "/ima2/{locus}.vcf.gz")
	shell:
		"""
		bcftools view -Oz -S {input.chosen} -r {wildcards.locus} {input.variant} > {output}
		tabix -p vcf {output}
		"""

### Before this step we need to remove the excess vcf header here
##using GATK 3.8
rule fastaMaker:
	input: outDir + "/var/singlevcf/{sample}.vcf"
	output: temp(outDir + "/fasta/{sample}.fasta")
	shell: 
		""""
		java -jar /apps/unit/MikheyevU/Maeva/GATK/GenomeAnalysisTK.jar -T FastaAlternateReferenceMaker -R {vdRef} -L "BEIS01000001.1:20000-30000" -V {input} -IUPAC {wildcard.sample} -o {output} 
		"""
rule vcf2GL:
	input: outDir + "/var/primitives.vcf.gz"
	output: temp(outDir + "/ngsadmix/all44/{chromosome}.BEAGLE.GL")
	shell:
		"""
		vcftools --gzvcf {input} --chr {wildcards.chromosome} --out /work/MikheyevU/Maeva/varroa-jump/data/ngsadmix/all44/{wildcards.chromosome} --BEAGLE-GL
		"""

rule mergeGL:
	input: expand(outDir + "/ngsadmix/all44/{chromosome}.BEAGLE.GL", chromosome = CHROMOSOMES)
	output: outDir + "/ngsadmix/all44/sevenchr.BEAGLE.GL"
	shell:
		"""
		(head -1 {input[0]}; for i in {input} do; cat $i | sed 1d; done) > {output}
		"""

rule vcf2GL_VD:
	input: outDir + "/var/perpopvar/vdonly.vcf.gz"
	output: temp(outDir + "/ngsadmix/vdGL/{chromosome}.BEAGLE.GL")
	shell:
		"""
		vcftools --gzvcf {input} --chr {wildcards.chromosome} --out /work/MikheyevU/Maeva/varroa-jump/data/ngsadmix/vdGL/{wildcards.chromosome} --BEAGLE-GL
		"""
		
rule mergeGL_VD:
	input: expand(outDir + "/ngsadmix/vdGL/{chromosome}.BEAGLE.GL", chromosome = CHROMOSOMES)
	output: outDir + "/ngsadmix/vdGL/sevenchr.BEAGLE.GL"
	shell:
		"""
		(head -1 {input[0]}; for i in {input} do; cat $i | sed 1d; done) > {output}
		"""

#rule NGSadmix:
#		input: outDir + "/[PATH]/xxx.BEAGLE.GL"
#		threads: 12
#		output: outDir + "[PATH]/xxx.lopt"
#		params: k = "2"
#		shell: "NGSadmix -P {threads} -likes {input} -K {params.k} -outfiles {output} -minMaf 0.1

