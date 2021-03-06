#We referred to the following webpages while working on this project:
#https://medium.com/@joyplumeri/how-to-make-interactive-maps-in-r-shiny-brief-tutorial-c2e1ef0447da
#https://rstudio.github.io/leaflet/popups.html
#https://appsilon.com/how-to-use-viridis-colors-with-plotly-and-leaflet/
#https://stackoverflow.com/questions/47824893/coloring-continuous-data-in-leaflet-r-does-not-work
#https://stackoverflow.com/questions/45776232/define-palette-breaks-for-leaflet
#http://www.r-tutor.com/elementary-statistics/numerical-measures/quartile
#http://www.r-tutor.com/elementary-statistics/numerical-measures/percentile
#http://rprogramming.net/recode-data-in-r/
#https://stackoverflow.com/questions/54283852/leaflet-colorquantile-breaks-are-not-unique
#https://stackoverflow.com/questions/54913505/invalid-type-list-of-argument-in-r
#https://stackoverflow.com/questions/34134310/sum-of-returned-list-error-invalid-type-list-of-argument
#Some of the map code is copied pretty closely from these sites.
#install.packages(c("shiny", "plotly", "dplyr", "readr", "leaflet", "rvest", "stringr", "readr", "ggplot2", "timeSeries", "ggfortify", "reshape2", "forecast", "viridis"))
library(shiny)
library(plotly)
library(dplyr)
library(readr)  
library(leaflet)
library(rvest)
library(stringr)
library(readr)
library(ggplot2)
library(timeSeries)
library(ggfortify)
library(reshape2)
library(forecast)
library(viridis)

# Source helper functions -----
source("source.R")

#--------------------------------------------------------------------------------------------------------------------#
#                                             DEFINE USER INTERFACE                                                  #
#--------------------------------------------------------------------------------------------------------------------#
# Define UI----
ui <- navbarPage (inverse= FALSE, "International Primary Energy Consumption and Production",
                  # First Page - Intro
                  tabPanel("Intro",
                           fluidPage(h1("Primary Energy Consumption and Production"),
                                     br(),
                                     p("International Primary Energy Consumption and Production related to Purchasing Power Parity (PPP) and Time (1980 - 2016)"),
                                     br(),
                                     div(p(strong("Built by"),  "Stella Lee, Patrick Min, and Nate Lu"), 
                                         p(strong("R Packages:"), "shiny, plotly, dplyr, readr, leaflet, rvest, stringr, readr, ggplot2, timeSeries, ggfortify, reshape2, forecast, viridis"),
                                         p(strong("Data Sources:"), a("U.S. Environmental Information Administration (eia)"), href = "https://www.eia.gov/beta/international/data/browser/#/?c=4100000002000060000000000000g000200000000000000001&vs=INTL.44-1-AFRC-QBTU.A&vo=0&v=H&end=2016"),
                                         p("See", a("Our GitHub Repository", href = "https://github.com/stellasylee/Energy"), "for more information")
                                     ))),
                  # Second Page - Map
                  tabPanel("Map",
                           fluidPage(
                             titlePanel("Energy Production and Consumption"),
                             sidebarLayout(
                               sidebarPanel(
                                 selectInput(inputId = "prod_or_cons",
                                             label = "Please choose an option:",
                                             choices = c("Production", "Consumption")),
                                 selectInput(inputId = "which_year",
                                             label = "Please choose a year:",
                                             choices = c("1980","1981","1982","1983","1984","1985","1986","1987","1988","1989",
                                                         "1990","1991","1992","1993","1994","1995","1996","1997","1998","1999",
                                                         "2000","2001","2002","2003","2004","2005","2006","2007","2008","2009",
                                                         "2010","2011","2012","2013","2014","2015","2016"))
                               ),
                               mainPanel({
                                 leafletOutput(outputId = "map")
                               })
                             ))),
                  # Third Page - Line Chart
                  tabPanel("Line Plot",
                           fluidPage(titlePanel("Consumption and Production of Each Country"),
                                     sidebarLayout(
                                       sidebarPanel(
                                         selectInput(inputId = "country", label = strong("Country:"),
                                                     choices = unique(cleanedPro$country),
                                                     selected = "Afghanistan"),
                                         checkboxInput(inputId = "ppp", # per capita scale
                                                       label = "Show PPP (Purchasing Power Parity)",
                                                       value = FALSE),
                                         checkboxInput(inputId = "log", 
                                                       label = "Show log scale ", # log scale
                                                       value = FALSE),
                                         checkboxInput(inputId = "perCapita", # per capita scale
                                                       label = "Show per capita scale",
                                                       value = FALSE),
                                         checkboxInput(inputId = "worldAvg", # world average line
                                                       label = "Show world production and consumption per capita ",
                                                       value = FALSE)
                                       ),
                                       mainPanel(
                                         plotlyOutput(outputId = "timeseries", height = "600px")
                                       )
                                     ))),
                  # Fourth Page - Timeseries Prediction
                  tabPanel("Timeseries Prediction",
                           fluidPage(titlePanel("Prediction of Each Country"),
                                     sidebarLayout(
                                       sidebarPanel(
                                         selectInput(inputId = "predProCons",
                                                     label = "Please choose an option:",
                                                     choices = c("Production", "Consumption")),
                                         selectInput(inputId = "predCountry", label = strong("Country:"),
                                                     choices = c(unique(production$country), "World"),
                                                     selected = "Afghanistan")
                                       ),
                                       mainPanel(
                                         plotlyOutput(outputId = "prediction", height = "600px")
                                       )
                                     )))
)

#--------------------------------------------------------------------------------------------------------------------#
#                                             DEFINE SERVER LOGIC                                                    #
#--------------------------------------------------------------------------------------------------------------------#
# Define server logic ----
server <- function(input, output) {
  # Map ----
  output$map <- renderLeaflet({
    if(input$prod_or_cons == "Production") {
      #opacity
      op <- ifelse(is.na(tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,]), .1, 1)
      production_label <- sprintf(
        "<strong>%s</strong><br/>Production: %g BTUs",
        (tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,])$country, (tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,])$prod
      ) %>% lapply(htmltools::HTML)
      leaflet(tidy_combined_production_table) %>% 
        setView(lng = 0, lat = 0, zoom = 2) %>% 
        addTiles() %>% 
        addCircles(data = tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,],
                   lat = (tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,])$Latitude, 
                   lng = (tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,])$Longitude, weight = 1, 
                   radius = 100000, 
                   color = (tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,])$circle_color, 
                   label = production_label, opacity = op) %>% 
        addLegend(colors = circle_colors, 
                  labels = c("Category 1 (least production)", "2", "3", "4", "5", "6", "7", "8 (greatest production)"), 
                  values = (tidy_combined_production_table[tidy_combined_production_table$year == input$which_year,])$circle_color, opacity = 0.7, 
                  title = "Production (in Giga BTUs)", position = "bottomright")
    } else if(input$prod_or_cons == "Consumption") {
      #opacity
      op <- ifelse(is.na(combined_consumption_table[,input$which_year]), .1, 1)
      consumption_label <- sprintf(
        "<strong>%s</strong><br/>Consumption: %g BTUs",
        (tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,])$country, (tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,])$cons
      ) %>% lapply(htmltools::HTML)
      leaflet(tidy_combined_consumption_table) %>%
        setView(lng = 0, lat = 0, zoom = 2) %>%
        addTiles() %>%
        addCircles(data = tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,],
                   lat = (tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,])$Latitude,
                   lng = (tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,])$Longitude,
                   weight = 1, radius = 100000,
                   color = (tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,])$circle_color,
                   label = consumption_label, opacity = op) %>% 
        addLegend(colors = circle_colors, 
                  labels = c("Category 1 (least consumption)", "2", "3", "4", "5", "6", "7", "8 (greatest consumption)"), 
                  values = (tidy_combined_consumption_table[tidy_combined_consumption_table$year == input$which_year,])$circle_color, 
                  opacity = 0.7, title = "Consumption (in Giga BTUs)", position = "bottomright")
    }
  })
  
  # Line Chart Consumption and Production of Each Country ----
  output$timeseries <- renderPlotly({
    # Special Case: Germany reunification at 1990
    if (paste(input$country) == "Germany"){
      temp <- cbind (as.data.frame(t(cleanedPop [which(cleanedPop$country == "Germany"),-1])),
                     as.data.frame(t(cleanedPPP [which(cleanedPPP$country == "Germany"),-1])),
                     as.data.frame(t(production [which(production$country == "Germany, East"), -1])),
                     as.data.frame(t(production [which(production$country == "Germany, West"), -1])),
                     as.data.frame(t(cleanedPro [which(cleanedPro$country == "Germany"),-1])), 
                     as.data.frame(t(consumption [which(consumption$country == "Germany, East"), -1])),
                     as.data.frame(t(consumption [which(consumption$country == "Germany, West"), -1])),
                     as.data.frame(t(cleanedCon [which(cleanedCon$country == "Germany"),-1])),
                     world)
      names(temp) <- c("population", "ppp", "proEast", "proWest", "production",
                       "conEast", "conWest", "consumption",  "worldPro", "worldCon", "worldPPP")
    } else {
      # Create data frame for plot
      temp <- cbind(as.data.frame(t(cleanedPop [which(cleanedPop$country == paste(input$country)),-1])),
                    as.data.frame(t(cleanedPPP [which(cleanedPPP$country == paste(input$country)),-1])),
                    as.data.frame(t(cleanedPro [which(cleanedPro$country == paste(input$country)),-1])),
                    as.data.frame(t(cleanedCon [which(cleanedCon$country == paste(input$country)),-1])),
                    world)
      names(temp) <- c("population", "ppp", "production", "consumption", "worldPro", "worldCon", "worldPPP")
    }
    
    # per capita data
    temp <- mutate(temp, proPerCapita = production / population) %>%
      mutate(., conPerCapita = consumption / population) %>%
      mutate(., pppPerCapita = ppp / population)
    
    if (input$log){
      temp <- log (temp[,-1])
    }
    
    p <- plot_ly(temp, x = ~colsn) %>%
      layout(title = paste(input$country),
             xaxis = list(title = "Year"),
             yaxis = list (title = "Primary Energy (Giga BTU)"))
    
    
    if ((input$ppp) && (input$perCapita)){
      p <- p %>%
        add_trace(y = ~pppPerCapita, name = 'purchasing power', mode = 'lines+markers', color = '#0000ff', type = 'scatter')
      if (input$worldAvg){
        p <- p %>%
          add_trace(y = ~worldPPP, name = 'world avg purchasing power', mode = 'lines+markers', color = '#000080', type = 'scatter') 
      }
    } else if (input$ppp){
      p <- p %>%
        add_trace(y = ~ppp, name = 'purchasing power', mode = 'lines+markers', color = 'blue', type = 'scatter')
    }
    
    
    if (input$perCapita){
      p <- p %>%
        add_trace(y = ~proPerCapita, name = 'production', mode = 'lines+markers', color = 'green', type = 'scatter') %>%
        add_trace(y = ~conPerCapita, name = 'consumption', mode = 'lines+markers', color = 'darkorchid', type = 'scatter')
    } else{
      p <- p %>%
        add_trace(y = ~production, name = 'production', mode = 'lines+markers', color = 'green', type = 'scatter') %>%
        add_trace(y = ~consumption, name = 'consumption', mode = 'lines+markers', color = 'darkorchid', type = 'scatter')
    }
    
    if ((paste(input$country) == "Germany") && (!input$perCapita)){
      p <- p %>%
        add_trace(y = ~proEast, name = 'production (East)', mode = 'lines+markers', color = 'yellowgreen', type = 'scatter') %>%
        add_trace(y = ~proWest, name = 'production (West)', mode = 'lines+markers', color = 'springgreen', type = 'scatter') %>%
        add_trace(y = ~conEast, name = 'consumption (East)', mode = 'lines+markers', color = 'orchid', type = 'scatter') %>%
        add_trace(y = ~conWest, name = 'consumption (West)', mode = 'lines+markers', color = 'lightcoral', type = 'scatter')
    }
    
    if (input$worldAvg && input$perCapita) {
      p <- p %>%
        add_trace(y = ~worldPro, name = 'world production', mode = 'lines+markers', color = 'olivedrab', type = 'scatter') %>%
        add_trace(y = ~worldCon, name = 'world consumption', mode = 'lines+markers', color = 'darkmagenta', type = 'scatter')
    } 
    p
  })
  
  # Page 4 ----
  output$prediction <- renderPlotly({
    if (input$predProCons == "Production"){
      if(paste(input$predCountry) == "World"){
        data <- world$`world pro`
      }else {
        data <- unname(unlist(production[production$country == paste(input$predCountry),-1]))
      }
      M2 = auto.arima(ts(data, frequency = 10), D=1)
      fore = forecast(M2)
    }else {
      if(paste(input$predCountry) == "World"){
        data <- world$`world pro`
      }else {
        data <- unname(unlist(consumption[consumption$country == paste(input$predCountry),-1]))
      }
      M2 = auto.arima(ts(data, frequency = 10), D=1)
      fore = forecast(M2)
    }
    
    plot_ly() %>%
      add_lines(x = time(data), y = data,
                color = I("black"), name = "observed") %>%
      add_ribbons(x = time(fore$mean)*8, ymin = fore$lower[, 2], ymax = fore$upper[, 2],
                  color = I("gray95"), name = "95% confidence") %>%
      add_ribbons(x = time(fore$mean)*8, ymin = fore$lower[, 1], ymax = fore$upper[, 1],
                  color = I("gray80"), name = "80% confidence") %>%
      add_lines(x = time(fore$mean)*8, y = fore$mean, color = I("blue"), name = "prediction") %>%
      layout(title = paste(input$predCountry),
             xaxis = list(title = "Year"),
             yaxis = list (title = "Primary Energy (Giga BTU)"))
  })
  
}

# Run the app ----
shinyApp(ui = ui, server = server)
