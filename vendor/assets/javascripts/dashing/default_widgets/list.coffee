class Dashing.List extends Dashing.Widget
  @::on 'data', ->
    if @get('unordered')
      $(@node).find('ol').remove()
    else
      $(@node).find('ul').remove()
