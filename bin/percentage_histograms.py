import matplotlib.pyplot as plot
import numpy as np
import sys

def loadandsave():
    vlxt_percentage = np.loadtxt('/home/oates/work/disorder/vlxt_percentages.dat')
    #outfile = open('/home/oates/work/disorder/vlxt_percentages.pkl', 'wb')
    #pickle.dump(vlxt_percentage,outfile,pickle.HIGHEST_PROTOCOL)
    #outfile.close()
    np.save('/home/oates/work/disorder/vlxt_percentages.npy',vlxt_percentage)
    vsl2b_percentage = np.loadtxt('/home/oates/work/disorder/vsl2b_percentages.dat')
    #outfile = open('/home/oates/work/disorder/vsl2b_percentages.pkl', 'wb')
    #pickle.dump(vsl2b_percentage,outfile,pickle.HIGHEST_PROTOCOL)
    #outfile.close()
    np.save('/home/oates/work/disorder/vsl2b_percentages.npy',vsl2b_percentage)

def load(filename):
    return np.load(filename)

vlxt_percentage = load('/home/oates/work/disorder/vlxt_percentages.npy')
vsl2b_percentage = load('/home/oates/work/disorder/vsl2b_percentages.npy')
hist, bins = np.histogram(vlxt_percentage,bins=100)
width=0.7*(bins[1]-bins[0])
center=(bins[:-1]+bins[1:])/2.0
plot.bar(center,hist,align='center',width=width)
#plot.set_title('VLXT % Disorder')
#plot.set_xlabel('% Amino Acids Disordered')
#plot.set_ylabel('Number of Proteins')
plot.show()

hist, bins = np.histogram(vsl2b_percentage,bins=100)
width=0.7*(bins[1]-bins[0])
center=(bins[:-1]+bins[1:])/2.0
plot.bar(center,hist,align='center',width=width)
#plot.set_title('VSL2b % Disorder')
#plot.set_xlabel('% Amino Acids Disordered')
#plot.set_ylabel('Number of Proteins')
plot.show()
