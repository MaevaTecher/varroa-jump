//Parameters for the coalescence simulation program : fsimcoal2.exe
2 samples to simulate :
//Population effective sizes (number of genes)
NVJAM0
NVJAC1
//Haploid Samples sizes and samples age 
15
7
//Growth rates	: negative growth implies population expansion
GAM
0
//Number of migration matrices : 0 implies no migration between demes
2
//Migration matrix 0
0 MAMtoAC
MACtoAM 0
//Migration matrix 1: No migration
0 0
0 0
//historical event: time, source, sink, migrants, new deme size, new growth rate, migration matrix index
1  historical event
TBOT 0 1 1 2 0 0
//Number of independent loci [chromosome] 
1 0
//Per chromosome: Number of contiguous linkage Block: a block is a set of contiguous loci
1
//per Block:data type, number of loci, per generation recombination and mutation rates and optional parameters
FREQ  1   0   1.25e-8 OUTEXP