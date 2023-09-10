// This file contains your Data Connector logic
[Version = "1.0.0"]
section woocommerce;

[DataSource.Kind="woocommerce", Publish="woocommerce.Publish"]


shared woocommerce.WooTables = (query as text, user as text, password as text) =>
    let
        objects = #table(
            {"Name",       "Key",         "Data",                 "ItemKind", "ItemName", "IsLeaf"},{
            {"Categories", "Categories",   WooCatAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Products",      "Products",  WooProdAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Products_Categories", "Products_Categories",  WooProdCatAPIImpl(query, user, password), "Table",    "Table",    true},
            {"Products_Variations", "Products_Variations",  WooProdAndVariationAPIImpl(query, user, password), "Table",    "Table",    true}                   
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
Source = Web.Contents(query & "/wp-json/wc/v3/products/categories", [ Headers = headers ]),
records = Json.Document(Source),
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
Source = Web.Contents(query & "/wp-json/wc/v3/products", [ Headers = headers ]),
records = Json.Document(Source),
#"Products Table" = Table.FromList(records, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
in
#"Products Table";


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
