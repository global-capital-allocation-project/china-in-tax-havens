# ------------------------------------------------------------------------------------------------------------------------------------------------------
# Network_Charts: This job generates the tax haven network charts 
# Note that the figure labeling is done via post-processing in Adobe Illustrator 
#                         only to change "Zother" to "other" as explained below.
# ------------------------------------------------------------------------------------------------------------------------------------------------------

library("dplyr")
library("ggplot2")
library("alluvial")
library("readxl")
library("stringr")
library("grid")
library("ggnewscale")
library("gridExtra")
library("Cairo")
library(extrafont)
font_import()
loadfonts(device="win")
fonts() 

# Global parameters
alpha <- 0.7 # transparency value

# Plotting function
gen_chart = function(dat, title="", color_palette=default_palette) {
  
  dat_ggforce <- dat  %>%
    gather_set_data(1:3) %>%
    arrange(x,Investor, Issuer, Company) %>%
    filter(restated_position_values>0.000)
  
  
  A_col = "#0A567D"
  B_col = "#963C3C"
  C_col = "#2D6D66"
  D_col = "#6B5957"
  E_col = "#1C84D1"
  F_col = "#A2B1B9"
    
  out = ggplot(dat_ggforce, aes(x=x, id=id, split=y, value=restated_position_values)) +
    geom_parallel_sets(aes(fill = Company), alpha = alpha, axis.width = 0.5,
                       n=100, strength = 0.5) +
    geom_parallel_sets_axes(axis.width = 0.55, fill = "gray96",
                            color = "gray80", size = 0.15, sep = 0.05) +
    geom_parallel_sets_labels(colour = 'gray35', size = 4, angle = 0) +
    scale_fill_manual(values  = c(A_col, B_col,  C_col, D_col, E_col, F_col)) +
    scale_x_continuous(position = "top", breaks = 1:3, labels = c("Investing Country", "Subsidiary Location", "Ultimate Parent Company")) +
    theme_minimal() +
    theme(
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      axis.text.y = element_blank(),
      axis.text.x = element_text(size = 16, family="Times New Roman", face="bold"),
      axis.title.x  = element_blank(),
      legend.position = "none"
    ) +
    ggtitle(title)
  
  return(out)
}

### Equities and Bonds
dat = readxl::read_excel("<DATA_PATH>/output/china_sankey_firm_estimates_combined.xls")
#In order to put the "other" observations at the bottom we name it as "ZOTHER" as this R code doesn't take in order/factor as an input.
dat$Company[dat$Company == "ZOTHER"] <- "ZOTHER COMPANIES"
bonds_equties_CHN = gen_chart(dat, title="")
bonds_equties_CHN
ggsave("<DATA_PATH>/output/network_flows_equitiesbonds_2020_CHN.pdf", device = cairo_pdf, 
       width = 12.25, height = 6.92, units = "in")
