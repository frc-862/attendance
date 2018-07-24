known = function(name) {
  return $("#names option").filter(function() {
    return $(this).val() === name;
  }).length > 0;
};

update_buttons = function(is_known) {
  $(".known").prop('disabled', !is_known);
  $(".unknown").prop('disabled', is_known);
};

handle_name = function() {
  update_buttons(known($(this).val()));
};

$(function() {
  $("#name").append($("#names > option").clone());
  $(".eselect").editableSelect().on('select.editable-select', handle_name);
  $("form.checkin #name").keyup(handle_name);
  $("form.checkin #name").change(handle_name);

  update_buttons(false);
});
