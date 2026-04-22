import os
import sys
import numpy as np
from simtk.openmm.app import *
from simtk.openmm import *
from simtk.unit import *
from sys import stdout
from simtk.openmm import XmlSerializer
import argparse
from parmed.amber import LoadParm
from parmed.openmm import RestartReporter
from mdtraj.reporters import XTCReporter

parser = argparse.ArgumentParser()

parser.add_argument('--prmtop', type=str, required=True)
parser.add_argument('--rst', type=str, required=True)
parser.add_argument('--output_name', type=str, required=True)
parser.add_argument('--restrain_list', type=str, required=True)

args = parser.parse_args()

### Simulation inputs
steps = 300000000
frame_steps = 25000  #number of steps to write a coordinate file (25000 steps * 0.004ps timestep = 100 ps frame saving rate)
data_steps = 1000000
timestep = 0.004*picoseconds

temperature = 300*kelvin #in Kelvin
pressure = 1.0*atmospheres 

#Inputs for Langevin integrator
friction = 1.41/picoseconds
NBcutoff = 1.0*nanometers

platform = Platform.getPlatformByName('CUDA')
platformProperties = {'Precision': 'mixed', 'DeviceIndex': '0'}

parm = LoadParm(args.prmtop)
inpcrd= AmberInpcrdFile(args.rst)

system = parm.createSystem(nonbondedMethod=PME,nonbondedCutoff=NBcutoff, constraints=HBonds, rigidWater=True)
system.addForce(MonteCarloBarostat(pressure,temperature,100))

### Add custom restraints
force10 = CustomExternalForce("k*periodicdistance(x, y, z, x0, y0, z0)^2")
force10.addGlobalParameter("k", 10.0*kilocalories_per_mole/angstroms**2)
force10.addPerParticleParameter("x0")
force10.addPerParticleParameter("y0")
force10.addPerParticleParameter("z0")

restraint_list = np.loadtxt(args.restraint_list)

#Apply harmonic restraints to atoms in outer shell
for i, atom_crd in enumerate(inpcrd.positions):
    if i in restraint_list:
        force10.addParticle(i, atom_crd.value_in_unit(nanometers))
system.addForce(force10)
### 

#Write system.xml file
dir = os.path.dirname(args.prmtop)
system_name = args.prmtop.replace(dir+'/','',1)
system_name = system_name.replace("-HMR.prmtop", "")

outfile = open(f"{system_name}_system.xml", 'w')
outfile.write(XmlSerializer.serialize(system))
outfile.close()

#Define the integrator
integrator = LangevinIntegrator(temperature, friction, timestep)

#Write integrator.xml file
outfile = open("integrator.xml", 'w')
outfile.write(XmlSerializer.serialize(integrator))
outfile.close()

#TRAJECTORY OUTPUT -----------------------------------------------------------------
output_file_name = args.output_name

xtc_file = f"{output_file_name}.xtc"
log_file = f"{output_file_name}.log"
chk_file = f"{output_file_name}.chk"
rst_out_file = f"{output_file_name}.rst"

#Check if out files exist to prevent overwrite
if os.path.isfile(xtc_file) == True or os.path.isfile(log_file) == True or os.path.isfile(chk_file) == True or os.path.isfile(rst_out_file) == True:
    print(f"Output files exist! Rename to prevent data overwriting.")
    exit()

xtcReporter = XTCReporter(xtc_file, frame_steps)  #frame save rate
dataReporter = StateDataReporter(log_file, data_steps, totalSteps=steps,
    step=True, speed=True, progress=True, elapsedTime=True, remainingTime=True, potentialEnergy=True, temperature=True, separator='\t')
checkpointReporter = CheckpointReporter(chk_file, frame_steps)
restartReporter = RestartReporter(rst_out_file,reportInterval=frame_steps,netcdf=False)

simulation = Simulation(parm.topology, system, integrator,platform, platformProperties)
simulation.context.setPositions(inpcrd.positions)
if inpcrd.boxVectors is not None:
    simulation.context.setPeriodicBoxVectors(*inpcrd.boxVectors)


simulation.context.setVelocitiesToTemperature(temperature)
simulation.context.setStepCount(0)

simulation.reporters.append(xtcReporter)
simulation.reporters.append(dataReporter)
simulation.reporters.append(checkpointReporter)
simulation.reporters.append(restartReporter)

simulation.step(steps)
