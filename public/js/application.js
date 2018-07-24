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
  var is_checked_in = checked_in($(this).val());
  $(".checkin").prop('disabled', !(is_known && !is_checked_in));
  $(".checkout").prop('disabled', !(is_known && is_checked_in));
  $(".unknown").prop('disabled', is_known);
};

$(function() {
  $("#name").keyup(handle_name);
  $("#name").change(handle_name);
});
