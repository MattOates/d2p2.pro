import matplotlib.pyplot as plot
import numpy as np
import sys

def loadandsave():
    vlxt_length = np.loadtxt('/home/oates/work/disorder/vlxt_disorder_length.dat')
    np.save('/home/oates/work/disorder/vlxt_disorder_length.npy',vlxt_length)
    
    vsl2b_length = np.loadtxt('/home/oates/work/disorder/vsl2b_disorder_length.dat')
    np.save('/home/oates/work/disorder/vsl2b_disorder_length.npy',vsl2b_length)

def load(filename):
    return np.load(filename)


vlxt_length = load('/home/oates/work/disorder/vlxt_disorder_length.npy')
vsl2b_length = load('/home/oates/work/disorder/vsl2b_disorder_length.npy')
hist, bins = np.histogram(vlxt_length,bins=3000)
width=0.7*(bins[1]-bins[0])
center=(bins[:-1]+bins[1:])/2.0
plot.bar(center,hist,align='center',width=width)
#plot.set_title('VLXT % Disorder')
#plot.set_xlabel('% Amino Acids Disordered')
#plot.set_ylabel('Number of Proteins')
plot.show()

hist, bins = np.histogram(vsl2b_length,bins=3000)
width=0.7*(bins[1]-bins[0])
center=(bins[:-1]+bins[1:])/2.0
plot.bar(center,hist,align='center',width=width)
#plot.set_title('VSL2b % Disorder')
#plot.set_xlabel('% Amino Acids Disordered')
#plot.set_ylabel('Number of Proteins')
plot.show()
