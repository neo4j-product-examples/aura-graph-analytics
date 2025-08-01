#install.packages("tidyverse")
library(tidyverse)

setwd("/Users/corydonbaylor/Documents/github/retail-fix")

# this contains all contents of those orders
baskets = read.csv("data/order_products__prior.csv")

# we just want to look at 1k baskets
baskets = baskets %>%
  filter(order_id < 1000)

# this is all the products
products = read.csv("data/products.csv")

# we just need products that are in our universe of baskets
products_f = products%>%
  filter(product_id %in% baskets$product_id)%>%
  # we also need to clean the names a little
  mutate(product_name = product_name %>%
           str_trim() %>%                        # Trim leading/trailing whitespace
           str_replace_all("[^A-Za-z\\s]", "") %>%  # Remove everything except letters and spaces
           str_squish()                          # Collapse multiple spaces to one
  )                                    # Trim whitespace

# this contains all the orders that they have made
# each row is a basket
order_history = read.csv("data/orders.csv")

# we only need the orders that are in our sample
# when we consider our order history
order_history_f = order_history%>%
  filter(order_id %in% baskets$order_id)

# we only need aisles and departments for products
# that were bought in the baskets in our sample
aisles = read.csv("data/aisles.csv")%>%
  filter(aisle_id %in% products_f$aisle_id)

departments = read.csv("data/departments.csv")%>%
  filter(department_id %in% products_f$department_id)

# output everything
write.csv(baskets, "output/baskets.csv", row.names = F)
write.csv(products_f, "output/products.csv", row.names = F)
write.csv(order_history_f, "output/order_history.csv", row.names = F)
write.csv(aisles, "output/aisles.csv", row.names = F)
write.csv(departments, "output/departments.csv", row.names = F)
