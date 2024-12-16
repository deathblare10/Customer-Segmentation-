library(shiny)
library(ggplot2)
library(dplyr)
library(cluster)
library(factoextra)
library(plotrix)



ui <- fluidPage(
  titlePanel("Customer Segmentation Analysis"),
  
  sidebarLayout(
    sidebarPanel(
      fileInput("file", "Upload Customer Data (CSV)", accept = ".csv"),
      h4("Data Cleaning"),
      checkboxInput("remove_duplicates", "Remove Duplicates", TRUE),
      checkboxInput("remove_na", "Remove Missing Values", TRUE),
      
      h4("Visualizations"),
      selectInput("plot_type", "Select Plot Type:",
                  choices = c("Gender Distribution" = "gender",
                              "Age Distribution" = "age",
                              "Annual Income Distribution" = "income",
                              "Spending Score Distribution" = "spending")),
      
      h4("Clustering Parameters"),
      numericInput("num_clusters", "Number of Clusters (K-means)", 4, min = 1, max = 10),
      actionButton("cluster", "Run Clustering")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Data Summary", verbatimTextOutput("summary")),
        tabPanel("Missing Values", verbatimTextOutput("missing")),
        tabPanel("Visualization", plotOutput("plot")),
        tabPanel("Clustering", 
                 plotOutput("clusterPlot"), 
                 verbatimTextOutput("silhouette"),
                 plotOutput("silhouettePlot"),
                 plotOutput("elbowPlot"))
      )
    )
  )
)

# Define server logic
server <- function(input, output) {
  customer_data <- reactive({
    req(input$file)
    data <- read.csv(input$file$datapath)
    
    if (input$remove_na) {
      data <- na.omit(data)
    }
    if (input$remove_duplicates) {
      data <- distinct(data)
    }
    return(data)
  })
  
  output$summary <- renderPrint({
    req(customer_data()) 
    summary(customer_data())
  })
  
  output$missing <- renderPrint({
    req(customer_data())
    missing_values <- colSums(is.na(customer_data()))
    total_missing <- sum(is.na(customer_data()))
    list(Column_Missing = missing_values, Total_Missing = total_missing)
  })
  
  output$plot <- renderPlot({
    req(customer_data())
    data <- customer_data()
    
    if (input$plot_type == "gender") {
      a <- table(data$Gender)
      barplot(a, main="Gender Distribution", col=rainbow(2))
    } else if (input$plot_type == "age") {
      data$AgeGroup <- cut(data$Age, breaks = c(18, 25, 35, 45, 55, Inf), 
                           labels = c("18-25", "26-35", "36-45", "46-55", "55+"))
      ggplot(data, aes(x = AgeGroup, fill = AgeGroup)) +
        geom_bar() +
        labs(title = "Age Distribution") +
        theme_minimal()
    } else if (input$plot_type == "income") {
      ggplot(data, aes(x = Annual.Income..k..)) +
        geom_density(fill = "blue", alpha = 0.5) +
        labs(title = "Annual Income Distribution")
    } else if (input$plot_type == "spending") {
      ggplot(data, aes(x = Spending.Score..1.100.)) +
        geom_density(fill = "green", alpha = 0.5) +
        labs(title = "Spending Score Distribution")
    }
  })
  
  output$clusterPlot <- renderPlot({
    req(input$cluster)
    data <- customer_data()[, c("Annual.Income..k..", "Spending.Score..1.100.")]
    
    kmeans_result <- kmeans(data, centers = input$num_clusters)
    fviz_cluster(kmeans_result, data = data, 
                 geom = "point", ellipse.type = "norm",
                 main = "K-means Clustering Results")
  })
  
  output$silhouette <- renderPrint({
    req(input$cluster)
    data <- customer_data()[, c("Annual.Income..k..", "Spending.Score..1.100.")]
    kmeans_result <- kmeans(data, centers = input$num_clusters)
    silhouette_avg <- silhouette_score(data, kmeans_result$cluster)
    
    paste("Average Silhouette Score:", silhouette_avg)
  })
  
  output$silhouettePlot <- renderPlot({
    req(customer_data())
    data <- customer_data()[, c("Annual.Income..k..", "Spending.Score..1.100.")]
    fviz_nbclust(data, kmeans, method = "silhouette") +
      labs(title = "Silhouette Method for Optimal Clusters")
  })
  
  output$elbowPlot <- renderPlot({
    req(customer_data())
    data <- customer_data()[, c("Annual.Income..k..", "Spending.Score..1.100.")]
    fviz_nbclust(data, kmeans, method = "wss") +
      labs(title = "Elbow Method for Optimal Clusters")
  })
}

silhouette_score <- function(data, clusters) {
  diss <- daisy(data)
  sil <- silhouette(clusters, diss)
  
  cat("Silhouette score formula: (b - a) / max(a, b)")
  
  mean(sil[, 3])
}

shinyApp(ui = ui, server = server)
