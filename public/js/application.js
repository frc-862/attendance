checked_in = function(name) {
  return $("#checked-in option").filter(function() {
    return $(this).val() === name;
  }).length > 0;
};

known = function(name) {
  return $("#names option").filter(function() {
    return $(this).val() === name;
  }).length > 0;
};

handle_name = function() {
  var is_known = known($(this).val());
  $(".known").prop('disabled', !is_known);
  $(".unknown").prop('disabled', is_known);
};

$(function() {
  $("form.checkin #name").keyup(handle_name);
  $("form.checkin #name").change(handle_name);
});
