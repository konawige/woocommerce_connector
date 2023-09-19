// This file contains your Data Connector logic
[Version = "1.0.0"]
section woocommerce;

[DataSource.Kind="woocommerce", Publish="woocommerce.Publish"]


shared woocommerce.WooTables = (query as text) =>
    let
        user = Record.Field(Extension.CurrentCredential(), "Username"),
        password = Record.Field(Extension.CurrentCredential(), "Password"),
        objects = #table(
            {"Name",       "Key",         "Data",                 "ItemKind", "ItemName", "IsLeaf"},{
            {"Categories", "Categories",   WooCatAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Products",      "Products",  WooProdAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Products Categories", "Products_Categories",  WooProdCatAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Products Variations", "Products_Variations",  WooProdAndVariationAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Orders", "Orders",  WooOrderAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Line Items Orders", "Line_Items",  WooOrderLineItemAPIImpl(query, user, password), "Table",    "Table",    true}                   
            }),
        NavTable = Table.ToNavigationTable(objects, {"Key"}, "Name", "Data", "ItemKind", "ItemName", "IsLeaf")
    in
        NavTable;

WooCatAPIImpl = (query as text, user as text, password as text) =>
let

identifier = user & ":" & password,
Bytes = Text.ToBinary(identifier),
Credentials = Binary.ToText(Bytes, BinaryEncoding.Base64),
headers = [
#"Authorization" = "Basic " & Credentials,
Accept = "application/json;"],
Response_Headers = Web.Headers(query & "/wp-json/wc/v3/products/categories?per_page=100", [ Headers = headers ]),
nb_pages = Number.FromText(Record.Field(Response_Headers, "X-WP-TotalPages")),
iterations = List.Generate(() => 1, each _ <= nb_pages, each _ + 1),
iteration_list = List.Transform(iterations, each Json.Document(Web.Contents(query & "/wp-json/wc/v3/products/categories?per_page=100&page=" &Text.From(_), [ Headers = headers ]))),
records = List.Combine(iteration_list),
#"Converted to Table" = Table.FromList(records, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
#"Expanded Categories" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", {"id","name","parent", "count"})
in
#"Expanded Categories";

WooFetchProduct = (query as text, user as text, password as text) =>
let
identifier = user & ":" & password,
Bytes = Text.ToBinary(identifier),
Credentials = Binary.ToText(Bytes, BinaryEncoding.Base64),
headers = [
#"Authorization" = "Basic " & Credentials,
Accept = "application/json;"],
Response_Headers = Web.Headers(query & "/wp-json/wc/v3/products?per_page=100", [ Headers = headers ]),
nb_pages = Number.FromText(Record.Field(Response_Headers, "X-WP-TotalPages")),
iterations = List.Generate(() => 1, each _ <= nb_pages, each _ + 1),
iteration_list = List.Transform(iterations, each Json.Document(Web.Contents(query & "/wp-json/wc/v3/products?per_page=100&page=" &Text.From(_), [ Headers = headers ]))),
records = List.Combine(iteration_list),
#"Products Table" = Table.FromList(records, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
in
#"Products Table";


WooFetchOrder = (query as text, user as text, password as text) =>
let
identifier = user & ":" & password,
Bytes = Text.ToBinary(identifier),
Credentials = Binary.ToText(Bytes, BinaryEncoding.Base64),
headers = [
#"Authorization" = "Basic " & Credentials,
Accept = "application/json;"],
Response_Headers = Web.Headers(query & "/wp-json/wc/v3/orders?per_page=100", [ Headers = headers ]),
nb_pages = Number.FromText(Record.Field(Response_Headers, "X-WP-TotalPages")),
iterations = List.Generate(() => 1, each _ <= nb_pages, each _ + 1),
iteration_list = List.Transform(iterations, each Json.Document(Web.Contents(query & "/wp-json/wc/v3/orders?per_page=100&page=" &Text.From(_), [ Headers = headers ]))),
records = List.Combine(iteration_list),
#"Orders Table" = Table.FromList(records, Splitter.SplitByNothing(), null, null, ExtraValues.Error)

in
#"Orders Table";


WooProdAPIImpl = (query as text, user as text, password as text) =>
let
#"Raw Product Table" = WooFetchProduct(query, user, password),
#"Expanded Products" = Table.ExpandRecordColumn(#"Raw Product Table", "Column1", {"id","name", "sku", "type", "date_created","date_modified" ,
"status", "price", "regular_price", "sale_price", "total_sales", "virtual", "downloadable", "tax_status", "tax_class", "manage_stock",
"stock_quantity", "stock_status", "backorders_allowed", "weight", "dimensions", "shipping_taxable", "reviews_allowed", "average_rating",
"rating_count", "parent_id"}), 
#"Expanded Products Dim" = Table.ExpandRecordColumn(#"Expanded Products", "dimensions", {"length","width", "height"})
in
#"Expanded Products Dim";

WooProdCatAPIImpl = (query as text, user as text, password as text) =>
let
#"Raw Product Table" = WooFetchProduct(query, user, password),
#"Expanded Products" = Table.ExpandRecordColumn(#"Raw Product Table", "Column1", {"id", "categories"}), 
#"Expanded Products Cat" = Table.ExpandListColumn(#"Expanded Products", "categories"),
#"Expanded Products Cat 2"= Table.ExpandRecordColumn(#"Expanded Products Cat", "categories", {"id"}, {"category id"}),
#"Final Products Cat"= Table.RenameColumns(#"Expanded Products Cat 2",{{"id", "product id"}})
in
#"Final Products Cat";

WooProdAndVariationAPIImpl = (query as text, user as text, password as text) =>
let
#"Raw Product Table" = WooFetchProduct(query, user, password),
#"Expanded Products" = Table.ExpandRecordColumn(#"Raw Product Table", "Column1", {"id", "variations"}), 
#"Expanded Products Var" = Table.ExpandListColumn(#"Expanded Products", "variations"),
#"Expanded Products Var 2" = Table.ReorderColumns(#"Expanded Products Var",{"variations", "id"}),
#"Expanded Products Var 3"= Table.RenameColumns(#"Expanded Products Var 2",{{"id", "product id"}, {"variations", "variation id"}}),
#"Final Products Variations" = Table.SelectRows(#"Expanded Products Var 3", each ([variation id] <> null))
in
#"Final Products Variations";

// ORDERS TABLE

WooOrderAPIImpl = (query as text, user as text, password as text) =>
let
#"Raw Order Table" = WooFetchOrder(query, user, password),
#"Expanded Orders" = Table.ExpandRecordColumn(#"Raw Order Table", "Column1", {"id", "parent_id", "number", "created_via", "status", "currency", 
"date_created", "date_created_gmt", "date_modified", "date_modified_gmt", "discount_total", "discount_tax", "shipping_total", "shipping_tax", "cart_tax", "total", "total_tax", 
"prices_include_tax", "customer_id", "customer_note", "billing", "shipping", "payment_method", "payment_method_title", 
"transaction_id", "date_paid", "date_paid_gmt", "date_completed", "date_completed_gmt"}), 
//Expand billing
#"Expanded Orders Billing"= Table.ExpandRecordColumn(#"Expanded Orders", "billing", {"first_name", "last_name", "company", "address_1", "address_2", "city", "state", "postcode",
 "country", "email", "phone"}, {"billing.first_name", "billing.last_name", "billing.company", "billing.address_1", "billing.address_2", "billing.city", "billing.state", 
 "billing.postcode", "billing.country", "billing.email", "billing.phone"}),
 //Expand shipping
 #"Expanded Orders Shipping"= Table.ExpandRecordColumn(#"Expanded Orders Billing", "shipping", {"first_name", "last_name", "company", "address_1", "address_2", "city", 
 "state", "postcode", "country"}, {"shipping.first_name", "shipping.last_name", "shipping.company", "shipping.address_1", "shipping.address_2", "shipping.city", 
 "shipping.state", "shipping.postcode", "shipping.country"})
in
#"Expanded Orders Shipping";

//LINE ITEMS ORDER TABLE 
WooOrderLineItemAPIImpl = (query as text, user as text, password as text) =>
let
#"Raw Order Table" = WooFetchOrder(query, user, password),
#"Expanded Orders" = Table.ExpandRecordColumn(#"Raw Order Table", "Column1", {"id", "line_items"}),
#"Expanded Orders Rename Id"= Table.RenameColumns(#"Expanded Orders",{{"id", "order id"}}),
#"Expanded Line Items"= Table.ExpandListColumn(#"Expanded Orders Rename Id", "line_items"),
#"Expanded Line Items With Rename"= Table.ExpandRecordColumn(#"Expanded Line Items", "line_items", {"id", "name", "product_id", "variation_id", "quantity", "tax_class", "subtotal", 
"subtotal_tax", "total", "total_tax","sku", "price", "parent_name"}, {"id", "product name", "product id", "variation id", "quantity", "tax class", 
"subtotal", "subtotal tax", "total", "total tax","sku", "price", "parent product name"})
in
#"Expanded Line Items With Rename";

Table.ToNavigationTable = (
    table as table,
    keyColumns as list,
    nameColumn as text,
    dataColumn as text,
    itemKindColumn as text,
    itemNameColumn as text,
    isLeafColumn as text
) as table =>
    let
        tableType = Value.Type(table),
        newTableType = Type.AddTableKey(tableType, keyColumns, true) meta 
        [
            NavigationTable.NameColumn = nameColumn, 
            NavigationTable.DataColumn = dataColumn,
            NavigationTable.ItemKindColumn = itemKindColumn, 
            Preview.DelayColumn = itemNameColumn, 
            NavigationTable.IsLeafColumn = isLeafColumn
        ],
        navigationTable = Value.ReplaceType(table, newTableType)
    in
        navigationTable;




// Data Source Kind description
woocommerce = [
    Authentication = [
        // Key = [],
        UsernamePassword = [],
        // Windows = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
woocommerce.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://powerbi.microsoft.com/",
    SourceImage = woocommerce.Icons,
    SourceTypeImage = woocommerce.Icons
];

woocommerce.Icons = [
    Icon16 = { Extension.Contents("woocommerce16.png"), Extension.Contents("woocommerce20.png"), Extension.Contents("woocommerce24.png"), Extension.Contents("woocommerce32.png") },
    Icon32 = { Extension.Contents("woocommerce32.png"), Extension.Contents("woocommerce40.png"), Extension.Contents("woocommerce48.png"), Extension.Contents("woocommerce64.png") }
];
