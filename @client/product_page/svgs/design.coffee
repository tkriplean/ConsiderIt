window.designSVG = (props) ->

  base_width = 81
  base_height = 80

  svg.setSize base_width, base_height, props

  fill_color = props.fill_color or 'black'
  style = props.style or {}

  SVG
    width: props.width 
    height: props.height
    viewBox: "0 0 #{base_width} #{base_height}" 
    version: "1.1" 
    xmlns: "http://www.w3.org/2000/svg" 
    style: style

    G
      strokeWidth: 1
      fill: fill_color

      PATH d: "M51.6631111,42.3617778 L73.4728889,20.552 C75.0053333,19.0195556 76.6248889,16.2551111 77.1591111,14.2586667 L77.7875556,11.9164444 L79.2497778,6.44622222 L80.7644444,0.791111111 L75.1128889,2.30222222 L69.64,3.76888889 L67.2977778,4.39644444 C65.3013333,4.93066667 62.536,6.55022222 61.0044444,8.08266667 L39.7777778,29.3093333 L25.6426667,13.7866667 C24.8568889,12.9244444 23.7857778,12.3831111 22.648,12.2613333 C22.6302222,12.2302222 22.6097778,12.1982222 22.5884444,12.1671111 L18.3155556,6.03022222 L2.68444444,0.633777778 L2.61777778,0.608888889 C2.608,0.606222222 2.59377778,0.602666667 2.58311111,0.599111111 C2.54844444,0.588444444 2.51733333,0.577777778 2.48177778,0.570666667 C2.44711111,0.56 2.41155556,0.552888889 2.37688889,0.549333333 C2.23022222,0.525333333 2.08711111,0.528 1.94755556,0.549333333 C1.91288889,0.553777778 1.87822222,0.560888889 1.84355556,0.570666667 C1.81155556,0.577777778 1.784,0.584888889 1.75288889,0.595555556 C1.59555556,0.644444444 1.44888889,0.717333333 1.31644444,0.818666667 C1.288,0.84 1.26044444,0.864 1.232,0.888888889 C1.19377778,0.923555556 1.15555556,0.961777778 1.12088889,1 C1.096,1.02844444 1.072,1.056 1.05066667,1.08444444 C0.963555556,1.2 0.889777778,1.33244444 0.840888889,1.47555556 C0.834666667,1.48888889 0.831111111,1.50666667 0.827555556,1.52 C0.816888889,1.55111111 0.809777778,1.57955556 0.803555556,1.61066667 C0.792888889,1.64622222 0.785777778,1.68088889 0.782222222,1.71555556 C0.758222222,1.85866667 0.760888889,2.00177778 0.782222222,2.14488889 C0.785777778,2.17955556 0.792888889,2.21511111 0.803555556,2.24977778 C0.810666667,2.28444444 0.821333333,2.31644444 0.831111111,2.35111111 C0.841777778,2.38577778 0.851555556,2.41777778 0.865777778,2.45244444 L6.26222222,18.0835556 L12.3991111,22.3564444 C12.4302222,22.3777778 12.4622222,22.3982222 12.4933333,22.416 C12.6124444,23.5644444 13.1457778,24.6151111 14.0186667,25.4106667 L29.5422222,39.5448889 L15.6488889,53.4382222 L10.1964444,58.8906667 C10.1937778,58.8933333 10.192,58.896 10.1893333,58.8986667 L8.20355556,60.8844444 C8.07555556,61.0124444 7.97955556,61.1608889 7.912,61.3182222 L7.91022222,61.3164444 L7.84,61.2462222 L3.28088889,65.8053333 C2.19555556,66.8906667 1.59822222,68.3395556 1.59822222,69.8791111 C1.59822222,71.4222222 2.19555556,72.8702222 3.28088889,73.9528889 L7.59911111,78.2746667 C8.68444444,79.36 10.1333333,79.9573333 11.6728889,79.9573333 C13.216,79.9573333 14.664,79.36 15.7502222,78.2746667 L20.3057778,73.7155556 L20.2355556,73.6453333 C20.3937778,73.5777778 20.5422222,73.4808889 20.6711111,73.352 L25.1573333,68.8657778 L28.1182222,65.9066667 C28.1288889,65.896 28.136,65.8888889 28.1422222,65.8791111 L42.5937778,51.4311111 L71.8568889,78.0755556 C72.8382222,78.9688889 74.1324444,79.4791111 75.4142222,79.4791111 C76.608,79.4791111 77.7004444,79.0462222 78.4897778,78.2577778 C80.1795556,76.568 80.0986667,73.5911111 78.3084444,71.6257778 L51.6631111,42.3617778 L51.6631111,42.3617778 Z M73.7342222,76.0124444 L44.5697778,49.4551111 L42.4995556,47.5733333 L39.8497778,45.1573333 L36.2337778,41.8657778 L33.584,39.4533333 L31.5173333,37.568 L15.8968889,23.3475556 C15.4951111,22.9813333 15.2684444,22.4888889 15.2577778,21.9617778 C15.2435556,21.4346667 15.4497778,20.9324444 15.8337778,20.5484444 L20.7804444,15.6017778 C21.1502222,15.2284444 21.6391111,15.0257778 22.1484444,15.0257778 C22.6933333,15.0257778 23.2026667,15.2524444 23.5795556,15.6684444 L37.8008889,31.2862222 L39.6826667,33.3528889 L42.0986667,36.0026667 L45.3902222,39.6186667 L47.8026667,42.272 L49.688,44.3386667 L76.2444444,73.5022222 C77.016,74.3537778 77.1448889,75.6524444 76.5128889,76.2808889 C76.2506667,76.5431111 75.8604444,76.6862222 75.4133333,76.6862222 C74.8204444,76.6862222 74.2097778,76.4417778 73.7342222,76.0124444 L73.7342222,76.0124444 Z M5.45955556,7.20355556 L9.98311111,11.7271111 C10.0391111,12.0693333 10.1991111,12.3973333 10.4613333,12.6595556 C10.7964444,12.9946667 11.2364444,13.1617778 11.6764444,13.1617778 C12.1164444,13.1617778 12.5564444,12.9946667 12.8915556,12.6595556 C13.5617778,11.9893333 13.5617778,10.904 12.8915556,10.2337778 C12.6266667,9.96888889 12.2977778,9.808 11.9564444,9.752 L7.43288889,5.22844444 L8.66133333,5.65066667 L16.5431111,8.37333333 L18.6168889,11.3511111 L19.7093333,12.9182222 C19.3848889,13.1137778 19.0808889,13.3511111 18.8053333,13.6266667 L13.8586667,18.5733333 C13.5831111,18.8488889 13.3457778,19.1493333 13.1502222,19.4737778 L11.5831111,18.3848889 L8.60533333,16.3146667 L5.88266667,8.42577778 L5.45955556,7.20355556 L5.45955556,7.20355556 Z M75.9093333,4.98311111 C76.0346667,4.95911111 76.1502222,4.94488889 76.2551111,4.94488889 C76.4364444,4.94488889 76.5342222,4.98666667 76.552,5.01155556 C76.5937778,5.064 76.664,5.28711111 76.552,5.73422222 L75.5777778,9.368 C74.6942222,9.31555556 73.8711111,8.94933333 73.2391111,8.31733333 C72.6071111,7.68533333 72.2408889,6.85155556 72.1884444,5.97866667 L75.9093333,4.98311111 L75.9093333,4.98311111 Z M62.9795556,10.0586667 C64.152,8.88622222 66.5084444,7.49955556 68.0204444,7.09511111 L69.4586667,6.70755556 C69.6613333,8.048 70.2826667,9.30844444 71.2631111,10.2888889 C72.2471111,11.2728889 73.4933333,11.8977778 74.8444444,12.0968889 L74.4604444,13.5315556 C74.0551111,15.0462222 72.6693333,17.4026667 71.4968889,18.576 L49.7777778,40.2951111 L47.3653333,37.6417778 L68.456,16.5546667 L65,13.0986667 L44.0737778,34.0257778 L41.6577778,31.376 L62.9795556,10.0586667 L62.9795556,10.0586667 Z M31.6088889,41.4266667 L34.2586667,43.8426667 L13.2195556,64.8808889 L12.1688889,63.8302222 C11.7777778,63.4355556 11.5617778,62.912 11.5617778,62.3466667 C11.5617778,61.8017778 11.7644444,61.2924444 12.1342222,60.9048889 C12.1386667,60.8986667 12.1448889,60.8933333 12.1493333,60.888 L15.3128889,57.7244444 L17.6248889,55.4142222 C17.6355556,55.4035556 17.6426667,55.3964444 17.6488889,55.3866667 L31.6088889,41.4266667 L31.6088889,41.4266667 Z M13.7742222,76.2986667 C13.216,76.8568889 12.472,77.1644444 11.6728889,77.1644444 C10.8773333,77.1644444 10.1333333,76.8568889 9.57511111,76.2986667 L5.25688889,71.9804444 C4.69866667,71.4222222 4.39111111,70.6782222 4.39111111,69.8791111 C4.39111111,69.0835556 4.69866667,68.3395556 5.25333333,67.7813333 L7.84,65.1982222 L16.3573333,73.7155556 L13.7742222,76.2986667 L13.7742222,76.2986667 Z M26.1422222,63.9306667 L20.6897778,69.3831111 C20.2951111,69.7777778 19.768,69.9937778 19.2062222,69.9937778 C18.6444444,69.9937778 18.1208889,69.7777778 17.7262222,69.3831111 L16.6755556,68.3324444 L37.8746667,47.1333333 L40.528,49.5457778 L26.1422222,63.9306667 L26.1422222,63.9306667 Z"