import os
import sys
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

parser.add_argument('--system', type=str, required=True)
parser.add_argument('--integrator', type=str, required=True)
parser.add_argument('--prmtop', type=str, required=True)
parser.add_argument('--rst', type=str, required=True)
parser.add_argument('--output_name', type=str, required=True)
parser.add_argument('-n', type=float, required=True)

args = parser.parse_args()

#Xml_read function ------------------------------------------------------------
def read_xml(file_path):
    with open(file_path, 'r') as f:
        xml = openmm.XmlSerializer.deserialize(f.read())
    return xml
##################

steps = args.n
frame_steps = 25000  #number of steps to write a coordinate file (25000 steps * 0.004ps timestep = 100 ps frame saving rate)
data_steps = 500000

integrator = read_xml(args.integrator)

system = read_xml(args.system)

platform = Platform.getPlatformByName('CUDA')
platformProperties = {'Precision': 'mixed', 'DeviceIndex': '0'}

#system_name = args.state.replace("_state.xml","")
#system_name = args.checkpoint.replace(".chk","")
system_name = args.rst.replace(".rst","")

prmtop = LoadParm(args.prmtop, args.rst)
rst = AmberInpcrdFile(args.rst)
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

simulation = Simulation(prmtop.topology, system, integrator,platform, platformProperties)
simulation.context.setPositions(rst.positions)
simulation.context.setVelocities(rst.velocities)
if prmtop.box_vectors is not None:
    simulation.context.setPeriodicBoxVectors(*prmtop.box_vectors)

simulation.reporters.append(xtcReporter)
simulation.reporters.append(dataReporter)
simulation.reporters.append(checkpointReporter)
simulation.reporters.append(restartReporter)

simulation.step(steps)
