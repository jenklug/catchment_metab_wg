# plotting load timeseries for figure 2

library(dplyr)
library(cowplot)
library(ggplot2)

### loading in metabolism data for sorting by mean GPP ###
dir<-'results/metab/20161107/' # directory of metabolism data
folders<-list.files(dir) # folders in this dir
folders<-folders[-grep('.doc',folders)] # get rid of README doc
folders<-folders[-grep('Trout',folders)] # skipping trout for now; have to do bootstrapping on this still

all_metab<-data.frame() # data frame to store all metab data
for(i in 1:length(folders)){ # loops over all folders in metab directory
  cur<-read.table(file.path(dir,folders[i],paste(folders[i],'_metabEst.txt',sep='')),header=T,sep='\t',
                  stringsAsFactors = F) # read in lake specific metab data
  cur<-cur[,1:12] # getting rid of any unnecessary columns
  cur$lake<-folders[i]
  all_metab<-rbind(all_metab,cur)
}

all_metab$date<-as.Date(paste(all_metab$year,all_metab$doy),format='%Y %j') # making date
all_metab <- as_tibble(all_metab)

season_cutoff <- readRDS('results/z_scored_schmidt.rds') %>%
  select(-doy)# seasonal cutoff based on z-scored schmidt stability
all_metab <- left_join(all_metab, season_cutoff, by = c('lake' = 'lake', 'date' = 'date'))

cv_cutoff = 10
min_doy = 120
max_doy = 300

metab_plot <- dplyr::filter(all_metab, doy > min_doy, doy < max_doy, GPP_SD/GPP < cv_cutoff) %>%
  group_by(lake) %>%
  summarise(mean_gpp = mean(GPP, na.rm=T),
            mean_R = mean(R, na.rm =T),
            mean_NEP = mean(NEP, na.rm=T)) %>%
  ungroup()

#### loading in nutrient load time series ###
dir<-'results/nutrient load/' # directory of load data
files<-list.files(dir) # folders in this dir
files<-files[-grep('Readme',files)] # get rid of README doc
files<-files[-grep('Trout', files)]

all_load<-data.frame() # data frame to store all load data
for(i in 1:length(files)){ # loops over all files in load directory
  cur<-read.table(file.path(dir,files[i]),header=T,sep='\t',
                  stringsAsFactors = F) # read in lake specific load data
  cur$lake<-strsplit(files[i], split = '_loads.txt')[[1]][1]
  all_load<-rbind(all_load,cur)
}

all_load <- as_tibble(all_load) %>%
  mutate(date = as.Date(Date)) %>%
  select(-Date)

season_cutoff <- readRDS('results/z_scored_schmidt.rds') %>%
  select(-doy)# seasonal cutoff based on z-scored schmidt stability
all_load <- left_join(all_load, season_cutoff, by = c('lake' = 'lake', 'date' = 'date'))

metaData <- read.csv('data/metadataLookUp.csv',stringsAsFactor=F) %>%
  select(Lake.Name, Volume..m3., Surface.Area..m2., Catchment.Area..km2., Lake.Residence.Time..year.)
all_load <- left_join(all_load, metaData, by = c('lake' = 'Lake.Name'))

min_doy = 120
max_doy = 300

load_plot <- dplyr::filter(all_load, doy > min_doy, doy < max_doy) %>%
  group_by(lake) %>%
  summarise(mean_tp_load = mean(TP_load / Volume..m3., na.rm=T),
            mean_tn_load = mean(TN_load / Volume..m3., na.rm =T),
            mean_doc_load = mean(DOC_load / Volume..m3., na.rm=T),
            mean_doc_tp_load = mean((DOC_load / 12) / (TP_load/31), na.rm=T)) %>%
  ungroup()

plot_data <- left_join(load_plot, metab_plot, by = 'lake')

#ordering by mean inflow
lakes_sorted <- plot_data$lake[sort.list(plot_data$mean_gpp)]
lakes_sorted <- as.character(lakes_sorted[!duplicated(lakes_sorted)])

plot_data$lake <- factor(plot_data$lake,levels = lakes_sorted)

# facet labeller
lake_names <- c('Acton' = 'Acton Lake',
                'Crampton' = 'Crampton Lake',
                'EastLong' = 'East Long Lake',
                'Feeagh' = 'Lough Feeagh',
                'Harp' = 'Harp Lake',
                'Langtjern' = 'Lake Langtjern',
                'Lillinonah' = 'Lake Lillinonah',
                'Lillsjoliden' = 'Lillsjöliden',
                'Mangstrettjarn' = 'Mångstrettjärn',
                'Mendota' = 'Lake Mendota',
                'Morris' = 'Morris Lake',
                'Nastjarn' = 'Nästjärn',
                'Ovre' = 'Övre Björntjärn',
                'Struptjarn' = 'Struptjärn',
                'Trout' = 'Trout Lake',
                'Vortsjarv' = 'Lake Võrtsjärv'
                )

cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7") # colorblind-friendly pallete

# keeping x and y axis scales the same for every plot
gpp_tp <- ggplot(plot_data, aes(x = mean_tp_load * 1000*1000, y = mean_gpp, group = lake)) +
  geom_point(size = 8) +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = 'inside',
        axis.title = element_text(size = 16),
        axis.text = element_text(size = 12),
        legend.title = element_blank(),
        legend.text = element_text(size =12)) +
  xlab(expression(TP~Load~(mg~m^-3~day^-1))) +
  ylab(expression(GPP~(mg~O[2]~L^-1~day^-1)))

gpp_tn <- ggplot(plot_data, aes(x = mean_tn_load * 1000*1000, y = mean_gpp, group = lake)) +
  geom_point(size = 8) +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = 'inside',
        axis.title = element_text(size = 16),
        axis.text = element_text(size = 12),
        legend.title = element_blank(),
        legend.text = element_text(size =12)) +
  xlab(expression(TN~Load~(mg~m^-3~day^-1))) +
  ylab(expression(GPP~(mg~O[2]~L^-1~day^-1)))

gpp_doc <- ggplot(plot_data, aes(x = mean_doc_load * 1000*1000, y = mean_gpp, group = lake)) +
  geom_point(size = 8) +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = 'inside',
        axis.title = element_text(size = 16),
        axis.text = element_text(size = 12),
        legend.title = element_blank(),
        legend.text = element_text(size =12)) +
  xlab(expression(DOC~Load~(mg~m^-3~day^-1))) +
  ylab(expression(GPP~(mg~O[2]~L^-1~day^-1)))

gpp_doc_tp <- ggplot(plot_data, aes(x = mean_doc_tp_load, y = mean_gpp, group = lake)) +
  geom_point(size = 8) +
  theme_classic() +
  theme(strip.background = element_blank(),
        strip.placement = 'inside',
        axis.title = element_text(size = 16),
        axis.text = element_text(size = 12),
        legend.title = element_blank(),
        legend.text = element_text(size =12)) +
  xlab(expression(Load~C:P~(mol:mol))) +
  ylab(expression(GPP~(mg~O[2]~L^-1~day^-1))) +
  scale_x_log10()

g = plot_grid(gpp_tp, gpp_tn, gpp_doc, gpp_doc_tp,
          labels = c('A', 'B', 'C', 'D'), align = 'hv',nrow = 2)

g

ggsave('figures/fig_gpp_loads.png', plot = g, width = 10, height = 10)

