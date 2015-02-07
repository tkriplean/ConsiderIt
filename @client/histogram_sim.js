//////
// Uses a d3-based physics simulation to calculate a reasonable layout
// of avatars within a given area. Also calculates (and returns) an
// avatar size. 

function positionAvatars(width, height, parent, opinions) {
  width = width || 400
  height = height || 70

  var opinions = opinions
                   .slice()
                   .sort(function (a,b) {return a.stance-b.stance}),
      n = opinions.length, // Number of opinions
      r,  // Radius of each node
      x_force_mult = 2,
      y_force_mult = height <= 100 ? 1 : 4,
      ratio_filled = .3,
      nodes, force

  //////
  // Calculate node radius based on size of area and number of nodes
  // (2*r)^2 * length == width * height * ratio_filled
  // (width * height / length) * 2 = (2*r)^2
  // sqrt(width * height / length * 2) = r
  r = Math.sqrt(width * height / opinions.length * ratio_filled)/2
  r = Math.min(r, width/2, height/2)

  // Travis: what's the purpose of this?
  if (opinions.length > 10) {
    // Now round r up until it fits perfectly within height
    var times_fit = height / (2*r)
    r = (height / (Math.floor(times_fit))) / 2 - .001
  }

  // Initialize positions of each node
  nodes = d3.range(opinions.length).map(function(i) {
    return {
      index: i, 
      radius: r,
      x: r + (width-r-r) * (i / n),
      y: r + Math.random() * (height - r-r)// r + (i * 400 / n) % (height-r-r)
    }
  })

  // see https://github.com/mbostock/d3/wiki/Force-Layout for docs
  force = d3.layout.force()
    .nodes(nodes)
    .on("tick", tick)
    .on('end', function () {console.log('simulation complete')})
    .gravity(0)
    .charge(0)
    .chargeDistance(0)
    .start()

  for (var i=0; i<opinions.length; i++)
    opinions[i].icon.style.width = opinions[i].icon.style.height = r*2 + 'px'

  // translates the opinion stance to a real x position in the bounding box
  function x_target(i) {
    return (opinions[i].stance + 1)/2 * width
  }

  // One iteration of the simulation
  function tick(e) {

    //////
    // Repel colliding nodes
    // A quadtree helps efficiently detect collisions
    var q = d3.geom.quadtree(nodes),
        i = 0
    while (++i < n)
      q.visit(collide(nodes[i]))

    //////
    // Apply standard forces
    nodes.forEach(function(o, i) {

      // Move for NaNs
      // Travis: How can a NaN occur?
      if (isNaN(o.y) || isNaN(o.x)) {
        console.error('Nan0 at', o.x, o.y)
        o.y = height/2
        o.x = x_target(o.index)//width/2
      }

      // Push node toward its desired x-location (e.g. stance)
      o.x += e.alpha * (x_force_mult * width  * .001) * (x_target(o.index) - o.x)

      // Push node downwards
      o.y += e.alpha * y_force_mult

      // Ensure node is still within the bounding box
      o.x = Math.max(r, Math.min(width  - r, o.x))
      o.y = Math.max(r, Math.min(height - r, o.y))

      // Re-position node
      opinions[i].icon.style.left = o.x - r + 'px'
      opinions[i].icon.style.top  = o.y - r + 'px'
    })
  }

  function collide(node) {
    // Travis: I understand what the 16 *does* but not the significance
    //         of the particular value. Does 16 make sense for all
    //         avatar sizes and sizes of the bounding box?
    var neighborhood_radius = node.radius + 16,
        nx1 = node.x - neighborhood_radius,
        nx2 = node.x + neighborhood_radius,
        ny1 = node.y - neighborhood_radius,
        ny2 = node.y + neighborhood_radius

    return function(quad, x1, y1, x2, y2) {

      // Repel two nodes if they overlap
      if (quad.leaf && (quad.point !== node)) {
        var dx = node.x - quad.point.x,
            dy = node.y - quad.point.y,
            dist = Math.sqrt(dx * dx + dy * dy),
            combined_r = node.radius + quad.point.radius

        if (dist < combined_r) {
          // repel both points equally in opposite directions
          separate_by = ( dist - combined_r ) / dist
          offset_x = dx * separate_by * .5
          offset_y = dy * separate_by * .5

          node.x -= offset_x
          node.y -= offset_y
          quad.point.x += offset_x
          quad.point.y += offset_y
        }
      }

      // visit subregions if we could possibly have a collision there
      return x1 > nx2
          || x2 < nx1
          || y1 > ny2
          || y2 < ny1
    }
  }

  // Returns calculated radius
  return r
}