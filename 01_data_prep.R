# 01_Data_Prep
# 

library(tidyverse)
library(sf)
library(terra)
library(FIESTA)
library(DBI)
# library(tmap)
# library(tmaptools)
library(RSQLite)
library(arcgisbinding)

con<-dbConnect(odbc::odbc(), .connection_string="driver={SQL Server};server=TESTGIS;database=SFInv;trusted_connection=yes")
dbListTables(con, catalog_name = "SFInv", schema_name = "dbo")

arc.check_product()

path <- "//file01/SFModelling/Western_Oregon_FMP/GISData/20230915_ModelDataPrep/wofmp_v1_scenario_input.gdb"
gdb<-arc.open(path)
gdb@children # to see ArcGIS layers
OML <- arc.data2sp(arc.select(arc.open(paste(gdb@path, "Ownership_ManagedLands", sep="/")))) # Districts
OML <- sf::st_as_sf(OML) # workaround to sf error due to missing geometry
HCA <- arc.data2sf(arc.select(arc.open(paste(gdb@path, "Biology_HabitatConservationArea", sep="/")))) # HCAs
HCA_agg <- st_union(st_make_valid(HCA))


# Unofficial management layer
# path<-"L:/Master_Data/ODF_Vector/SF_SDEexport.gdb"
# gdb<-arc.open(path)
# MHO<-arc.data2sp(arc.select(arc.open(paste(gdb@path, "MANAGEMENT_HARVESTOPERATIONS", sep="/"))))

# confidential locations
# needed for PROJECT ("FIA Base Grid" vs "ODF Spatial Intensification")
# and ODF_DISTRICT columns
locs<-dbGetQuery(con, "SELECT * FROM odf.plot_confidential_2021")
locs_sf<-st_as_sf(locs, coords=c(x="PC_LON_X", y="PC_LAT_Y"), crs=4269)


ODFplt <- dbGetQuery(con,"SELECT * FROM plot_public")
names(ODFplt) <- toupper(names(ODFplt))
ODFcond<- dbGetQuery(con,"SELECT * FROM cond")
names(ODFcond) <- toupper(names(ODFcond))
ODFtree <- dbGetQuery(con,"SELECT * FROM tree_public")
names(ODFtree) <- toupper(names(ODFtree))

tcc <- rast("data/nlcd_tcc_conus_2020_v2021-4_BjioapCBl9i5iFfrWEH7.tiff")

# TODO what CRS to transform everything to?
OML_4269 <- st_transform(OML, crs=st_crs(locs_sf))
HCA_agg_4269 <- st_transform(HCA_agg, crs=st_crs(locs_sf))

# HCAs by District
test1 <- st_intersection(OML_4269, HCA_agg_4269)
sf_use_s2(FALSE) # fix to unknown error
HCA_district <- test1 %>% 
  group_by(DISTRICT) %>% 
  summarise(geometry = st_union(geometry))
test2 <- st_difference(OML_4269, HCA_agg_4269)
nonHCA_district <- test2 %>% 
  group_by(DISTRICT) %>% 
  summarise(geometry = st_union(geometry))

# TODO: what to do about all the tiny lines leftover when HCAs substracted from OML?

# NEXT:
# See how FIA plots intersect with HCAs, add column
# Classify TCC for stratification
# FIESTA model-assisted carbon by district is the goal (2011-2020 base vs 2020 densified)
