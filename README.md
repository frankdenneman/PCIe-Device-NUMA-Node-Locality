# PCIe-to-NUMA-Mapping
Scriptset to enumerate PCIe Device to NUMA mapping within an VMware ESXi Host 
More info soon

Due to the character of new workloads, the PCIe device is quickly moving up from "just" being a peripheral device to become the primary unit for data processing. Two great examples of this development are the rise of General Purpose GPU (GPGPU), often referred to as GPU Compute, and the virtualization of the telecommunication space.

The concept of GPU computing implies using GPUs and CPUs together. In many new workloads, the processes of an application are executed on a few CPU cores, while the GPU, with its many cores, handles the computational intensive data-processing part. Another workload, or better said, a whole industry that leans heavily on the performance of PCIe devices, is the telecommunication industry. Virtual Network Functions (VNF) require platforms using SR-IOV capable NICs or SmartNICs to provide ultra-fast packet processing performance.

In both scenarios having insight into PCIe Device to processor locality is a must to provide the best performance to the application or avoid introducing menacing noisy neighbors that can influence the performance of other workloads active in the system.

## PCIe Device NUMA Node Locality

The majority of servers used in VMware virtualized environments are two-socket systems. Each socket accommodates a processor containing several CPU cores. A processor contains multiple memory controllers offering a connection to directly connected memory. An interconnect (Intel: QuickPath Interconnect (QPI) & UltraPath Interconnect (UPI), AMD: Infinity Fabric (IF)) connects the two processors and allows the cores within each processor to access the memory connected to the other processor. When accessing memory connected directly to the processor, it is called local memory access. When accessing memory connected to the other processor, it is called remote memory access. This architecture provides Non-Uniform Memory Access (NUMA) as access latency, and bandwidth differs between local memory access or remote memory access. Henceforth these systems are referred to as NUMA systems. 

It was big news when the AMD Opteron and Intel Nehalem Processor integrated the memory controller within the processor. But what about PCIe devices in such a system?  Since the Sandy Bridge Architecture (2009), Intel reorganized the functions critical to the core and grouped them in the Uncore, which is a "construct" that is integrated into the processor as well. And it is this Uncore that handles the PCIe bus functions. It provides access to NVMe devices, GPUs, and NICs. Below is a schematic overview of a 28 core Intel Sky lake processor showing the PCIe ports and their own PCIe root stack.

Insert Skylake schema

In essence, a PCIe device is hardwired to a particular port on a processor. And that means that we can introduce another concept to NUMA locality, which is PCIe locality.  Considering PCIe locality when scheduling low-latency or GPU compute workload can be beneficial not only to the performance of the application itself but also to the other workloads active on the system.

![Screenshot](02-PCIe%20Device%20NUMA%20Node%20Locality%20Venn%20Diagram.png)

For example, Machine Learning involves processing a lot of data, and this data flows within the system from the CPU and memory subsystem to the GPU to be processed. Properly written Machine Learning application routines minimize communication between the GPU and CPU once the dataset is loaded on the GPU, but getting the data onto the GPU typically turns the application into a noisy neighbor to the rest of the system. Imagine if the GPU card is connected to NUMA node 0, and the application is running on cores located in NUMA node 1. All that data has to go through the interconnect to the GPU card. 

The interconnect provides more theoretical bandwidth than a single PCIe 3.0 device can operate at, ~40 GB/s vs. 15 GB/s. But we have to understand that interconnect is used for all PCIe connectivity and memory transfers by the CPU scheduler. If you want to explore this topic more, I recommend reviewing Amdahl's Law - Validity of the single processor approach to achieving large scale computing capabilities - published in 1967.  Did you think this was a new problem we are solving? And the strongly related Little's Law. 

Keeping the application processes and data-processing software components on the same NUMA node keeps the workloads from flooding the QPI/UPI/aIF interconnect. 

For VNF workloads, it is essential to avoid any latency introduced by the system. Concepts like VT-d (Virtualization Technology for Directed I/O) reduces the time spent in a system for IOs and isolate the path so that no other workload can affect its operation. Ensuring the vCPU operates within the same NUMA domain ensures that no additional penalties are introduced by traffic on the interconnect and ensures the shortest path is provided from the CPU to the PCIe device.

## Constraining CPU placement
The PCIe Device NUMA Node Locality script assists in obtaining the best possible performance by indentifying the PCIe locality of GPU, NIC of FPGA PCIe devices. Typically VMs running the workloads as mentioned earlier are configured with a PCI passthrough enabled device. As a result, the script informs you which VMs are attached directly to the particular PCIe devices.  

Currently, the VMkernel schedulers do no provide any automatic placement based on PCIe locality. CPU placement can be constraint by associating those virtual machines with a specific NUMA node using an advanced setting.

Please note that applying this setting can interfere with the ability of the ESXi NUMA scheduler to rebalance virtual machines across NUMA nodes for fairness. Specify NUMA node affinity only after you consider the rebalancing issues.
