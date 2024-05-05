# fern-scanner
Biome map generation using cc-tweaked and advanced peripherals. Map rendering with Tom's peripherals

Definition of region, tile, and chunk
* Chunks are the same as minecraft chunks
 - The turtles take samples of the biomes from each chunk
 - Each chunk represents a pixel on the map
 - cX, cZ = x//16, z//16
 - Chunk coordinates of c{-3,5} would correspond to all the blocks between (-48,80) to (-33,95), inclusive
* Regions are NOT the same as minecraft regions
 - Regions are a 128x128 set of chunks (This works out to be 16384 chunks, whose data fit well into cc tweaked disks)
 - Turtles group their chunk data inside region files
 - rX, rZ = cX//128, cZ//128 = x//2048, z//2048
 - r<0,2> = c{0,256} to c{127,383} inc. = (0,4096) to (2047,6143) inclusive
* Tiles are the largest grouping
 - Tiles are a 2x2 set of regions, which are assigned to each turtle
 - tX, tZ = rX//2, rZ//2 = cX//256, cZ//256 = x//4096, z//4096
 - t[1,0]> = r<2,0> to r<3,1> inc. = c{256,0} to c{511,255} inc. = (4096,0) to (8191,4095) inclusive
