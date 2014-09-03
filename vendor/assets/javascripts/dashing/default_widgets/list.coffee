class Dashing.List extends Dashing.Widget
  @::on 'ready', ->
    if @get('unordered')
      $(@node).find('ol').remove()
    else
      $(@node).find('ul').remove()
