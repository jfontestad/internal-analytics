visualize.portfolio_sessions_all <- function(viz=as.viz("portfolio_sessions_all")){

  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(RColorBrewer)
  library(grid)

  deps <- readDepends(viz)

  height = viz[["height"]]
  width = viz[["width"]]
  bar_line_col = viz[["bar_line_col"]]
  text_col = viz[["text_col"]]

  summary_data_full <- deps[["sessions_all"]]
  min_app <- select(summary_data_full, bin, type, sessions, longName) %>%
    #filter to year data
    filter(grepl(pattern = "Year", x = type)) %>%
    group_by(bin) %>%
    slice(which.min(sessions))

  # decide where to place text
  max_vals <- summary_data_full %>%
    group_by(type) %>%
    summarize(max_val = max(scaled_value, na.rm = TRUE))

  summary_data_full <- summary_data_full %>%
    left_join(max_vals, by = "type") %>%
    mutate(text_placement = scaled_value + 0.06*max_val)
  # prepare dimensions for each pane that won't truncate the text values
  dummy_for_ylims <- summary_data_full %>%
    select(bin, type, longName, scaled_value, max_val) %>%
    group_by(bin, type) %>%
    arrange(desc(scaled_value)) %>%
    slice(1) %>%
    ungroup() %>%
    as.data.frame() %>%
    mutate(scaled_value = max_val*1.15,
           type = factor(type, levels = unique(summary_data_full$type)))

  summary_data_full <- summary_data_full %>%
    mutate(trend_complete = paste(trend, complete),
           type = factor(type, levels = unique(summary_data_full$type)))
  # define scales for shape, color, and fill
  shps <- c("none"=21,
            "up"=24,
            "down"=25,
            "geo" = NA)
  cols <- c("none" = viz[["trend_color"]]$none,
            "up" = viz[["trend_color"]]$up,
            "down" = viz[["trend_color"]]$down,
            "geo" = viz[["trend_color"]]$none)
  colfunc <- colorRampPalette(c("grey75","grey95"))
  fills <- colfunc(4)
  names(fills) <- levels(summary_data_full$bin)

  fills <- c(fills,
             setNames(cols, paste(names(cols), 'TRUE')),
             setNames(rep('white', 4), paste(names(cols), 'FALSE')))

  graph_body <- ggplot(data = summary_data_full,
                       aes(x = longName, y = scaled_value)) +
    facet_grid(bin ~ type, scales = "free",
               space = "free_y", drop = TRUE) +
    geom_rect(aes(fill = bin),xmin = -Inf,xmax = Inf,
              ymin = -Inf,ymax = Inf,color = NA) +
    geom_segment(aes(xend = longName), yend=0, size = 0.65, color = bar_line_col) +
    geom_segment(aes(xend = longName, y = scaled_newUser),
                 yend=0, col=bar_line_col, size=1.15) +
    geom_text(aes(label = session_text, y = text_placement, color = trend),
              size = 3, hjust = 0,
              data = summary_data_full) +
    geom_point(aes(shape=trend, fill = trend_complete, color=trend),
               data = summary_data_full) +
    #NOTE: because  geom_blank line uses a new data frame, it will overwrite the facet
    #orders from factor levels in summary_data_full if it doesn't
    #have the same level order
    geom_blank(data=dummy_for_ylims) +
    coord_flip() +
    scale_color_manual(values = cols) +
    scale_fill_manual(values = fills) +
    scale_shape_manual(values = shps) +
    theme_bw() +
    theme(axis.title = element_blank(),
          axis.text.x =  element_blank(),
          strip.text.y = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.border = element_blank(),
          strip.background = element_blank(),
          axis.ticks=element_blank(),
          legend.position = "none",
          plot.caption = element_text(hjust = 0)
    )

  info_graph <- ggplot_build(graph_body)
  layout_stuff <- info_graph$layout

  if(packageVersion("ggplot2") >= "2.2.1.9000"){
    lower_ranges <- layout_stuff$panel_scales_y[[2]]$range$range
    high_ranges <- layout_stuff$panel_scales_y[[1]]$range$range
  } else {
    lower_ranges <- layout_stuff$panel_ranges[[8]]$x.range
    high_ranges <- layout_stuff$panel_ranges[[4]]$x.range
  }

  ymin <- 0.40*(diff(lower_ranges))+lower_ranges[1]
  ymax <- 0.98*(diff(lower_ranges))+lower_ranges[1]

  ystart <- 0.45*(diff(lower_ranges))+lower_ranges[1]
  ymid <- 0.55*(diff(lower_ranges))+lower_ranges[1]
  yend <- 0.95*(diff(lower_ranges))+lower_ranges[1]

  bin_mid <- 0.99*(diff(high_ranges))+high_ranges[1] + 0.1

  low_df <- summary_data_full %>%
    filter(grepl(pattern = "Month", x = type),
           bin == "Low",
           longName %in% rev(levels(summary_data_full$longName)[1:6]))%>%
    arrange(longName)

  #Check if any of the 5 bottom months are higher than ymin:
  while(any(low_df$text_placement > ymin)){
    #TODO: if all the longName text placements are in the way of the legend, switch over to week.
    # and if that doesn't work....move x limit of graph
    viral_index <- which(low_df$text_placement > ymin)

    low_df <- summary_data_full %>%
      filter(grepl(pattern = "Month", x = type),
             bin == levels(summary_data_full$bin)[4],
             longName %in% rev(levels(summary_data_full$longName)[(viral_index+1):(viral_index + 6)])) %>%
      arrange(longName)

  }

  low_df <- low_df %>%
    arrange(desc(longName))

  text_df <- data.frame(label = c("Very High Traffic","High Traffic",
                                  "Moderate Traffic","Low Traffic"),
                        type = factor(x = grep(unique(summary_data_full$type),
                                               pattern = "Year", value = TRUE),
                                      levels = unique(summary_data_full$type)),
                        bin = factor(levels(summary_data_full$bin),
                                     levels = levels(summary_data_full$bin)),
                        longName = 1.75,  #these two control "high traffic", "Moderate traffic" etc
                        y = bin_mid, #labels.  Note that axes are flipped in this plot
                        stringsAsFactors = FALSE)

  fake_legend <- data.frame(label = c("Total Sessions","New Users","Trending Up**","Trending Down**","No Trend**","Missing >10%"),
                            type = low_df$type,
                            bin = low_df$bin,
                            longName = low_df$longName,
                            ymin = ymin, #box around legend
                            ystart = ystart, # start of lines within legend
                            ymid = ymid, # end of lines within legend
                            yend = yend, # start of text
                            ymax = ymax, # box around legend
                            trend = c(NA, NA, "up", "down", "none",NA),
                            trend_complete = c(NA, NA, "up TRUE", "down TRUE", "none TRUE", NA),
                            stringsAsFactors = FALSE)

  fake_legend$mid_mid <- fake_legend$ystart + (fake_legend$ymid - fake_legend$ystart)/2
  filled_legend <- data.frame(
    type = low_df$type[1],
    bin = low_df$bin[1],
    longName = fake_legend$longName[6],
    y = c(ystart,fake_legend$mid_mid[1],ymid),
    shapes = names(shps) %>% grep(pattern = "geo", invert = TRUE, value = TRUE),
    col = names(cols) %>% grep(pattern = "geo", invert = TRUE, value = TRUE),
    stringsAsFactors = FALSE
  )

  port_graph <- graph_body +
    geom_label(data = text_df,
               aes(x = longName, y = y, label = label), fill="white", color="black",
               size = 3.5, hjust = "right", label.r = unit(0, "lines")) +
    geom_rect(data = fake_legend[1,], inherit.aes=FALSE, # aes(y = 0),
              ymin = fake_legend$ymin[1] - 0.15,
              ymax = fake_legend$ymax[1],
              xmin = min(as.numeric(low_df$longName)) - 0.6,
              xmax = max(as.numeric(low_df$longName)) + 0.6,
              color = "black", fill = "white") +
    geom_text(data = fake_legend,
              aes(x = longName, y = yend, label = label),
              size = 3.5, hjust = "right", col = "black") +
    geom_segment(data = fake_legend[2,],
                 aes(x = longName,
                     xend = longName,
                     y = ystart - 0.15, yend=ymid - 0.15), col=bar_line_col, size=1.15) +
    geom_segment(data = fake_legend[1,],
                 aes(xend = longName, y=ystart - 0.15, yend=ymid - 0.15),
                 size=0.65, col=bar_line_col) +
    geom_point(data = fake_legend[3:5,],
               aes(x = longName, y=mid_mid - 0.15,
                   shape=trend, color=trend,
                   fill=trend_complete)) +
    geom_point(data = filled_legend,
               aes(x = longName,y =y - 0.15,
                   shape = shapes,
                   color = col), fill = "white") +
    labs(caption = "*Measures how proportional user location is to US state population, from 0 to 1. A value of one represents user locations exactly proportional to state population.
**Trends do not reflect year-over-year changes.  They are calculated only within the time period listed in the title, and often reflect seasonal usage cycles.")

  ggsave(port_graph, file = viz[["location"]], height = height, width = width)

}

