# Network Simulator (NetSim)

This tool uses Linux network namespaces to isolate instances of Wavelet
such that they can communicate over a shared IP network space only with
each other, and in a controlled network environment, while sharing all
of the rest of the host system.

The `node-classes/` directory contains code for classes of nodes within
the simulator.

The `playbooks/` directory contains code to run a particular simulation
given a set of nodes, constructed in a specific order, and running
specific code upon startup.

Usage:
```
./network-sim <playbookName>
```

Example:
```
./network-sim simple
```

The output from each node is writte in to the `work/` directory.
