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

rjust = function(string, width, padding) {
	padding = padding || " ";
	padding = padding.substr(0, 1);
  string = "" + string;
	if (string.length < width)
		return padding.repeat(width - string.length) + string;
	else
		return string;
};

update_duration = function() {
  var start = new Date($("#duration").data("checkin"));
  var now = new Date();
  var seconds = Math.round((now - start) / 1000);
  var minutes = Math.floor(seconds / 60);
  seconds -= minutes * 60;
  var hours = Math.floor(minutes / 60);
  minutes -= hours * 60;
  $("#duration").text(`${hours}:${rjust(minutes,2,"0")}:${rjust(seconds,2,"0")}`);
};

$(function() {
  $("#name").append($("#names > option").clone());
  $(".eselect").editableSelect().on('select.editable-select', handle_name);
  $("form.checkin #name").keyup(handle_name);
  $("form.checkin #name").change(handle_name);

  if ($("span#duration").length > 0) {
    setInterval(update_duration, 1000);
  }

  update_buttons(false);
});
