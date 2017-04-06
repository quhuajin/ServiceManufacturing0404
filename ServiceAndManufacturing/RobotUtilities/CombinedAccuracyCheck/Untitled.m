close all
hgs = hgs_robot('172.16.16.100');
n = ndi_camera(hgs)
init(n)
init_tool(n,'112220_RIO.rom')
plot(n)
