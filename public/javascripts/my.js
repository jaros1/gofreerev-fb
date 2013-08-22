// freeze user_currency when user enters text for new gift (auto submit when currency changes)
function gifts_index_disabled_user_currency() {
    var currency_id ;
    currency_id = document.getElementById('user_currency');
    alert('gifts_index_disabled_user_currency, isDisabled = ' + currency_id.isDisabled) ;

    currency_id.disabled = true ;
    var field_id ;
    field_id = document.getElementById('gift_price') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
    field_id = document.getElementById('gift_description') ;
    if (field_id.value != '') { currency_id.disabled = true ; return }
    field_id = document.getElementById('gift_file') ;
    if (field_id.value != '') { currency_id.disabled = true }
} // gifts_index_disabled_user_currency


// functions used in page header. Update user currency and return to current page
function pre_update_currency()
{
  // use this function to check for other pending changes in currency page before submit
  // eg a confirm popup or maybe copy not saved information to hidden variables in update_currency_form before submit
  return true ; // continue
  return false ; // stop
} // update_currency_ok
function update_currency()
{
   // check if submit is ok (are there other pending changes in page?)
   if (!pre_update_currency()) return ;
   // get selected currency
   var user_currency_new_id ;
   var user_currency_new ;
   var update_currency_div_id ;
   var update_currency_form_id ;
   var user_currency_id ;
   user_currency_new_id = document.getElementById('user_currency_new') ;
   user_currency_new = user_currency_new_id.value ;
   // copy selected currency to hidden form and submit
   update_currency_div_id = document.getElementById('update_currency_div') ;
   update_currency_form_id = update_currency_div_id.getElementsByTagName('Form')[0] ;
   user_currency_id = document.getElementById('user_new_currency') ;
   user_currency_id.value = user_currency_new ;
   update_currency_form_id.submit() ;
} // update_currency_submit

// Version of pre_update_currency to be used in gifts controller pages
var pending_gift_msg = 'Update currency?' ;
function gifts_pre_update_currency()
{
    // get selected currency
    var user_currency_new_id ;
    var user_currency_new ;
    var update_currency_div_id ;
    var update_currency_form_id ;
    var user_currency_id ;
    user_currency_new_id = document.getElementById('user_currency_new') ;
    user_currency_new = user_currency_new_id.value ;
    if (user_currency_new == '<%= @user.currency %>') return false ;
    // check for pending new gift
    var pending_data = false ;
    field_id = document.getElementById('gift_price') ;
    if (field_id.value != '') pending_data = true ;
    field_id = document.getElementById('gift_description') ;
    if (field_id.value != '') pending_data = true ;
    field_id = document.getElementById('gift_file') ;
    if (field_id.value != '') pending_data = true ;
    if (!pending_data) return true ; // no pending gift
    // confirm box
    return (confirm(pending_gift_msg)) ;
} // gifts_pre_update_currency()


// Client side validations
// https://github.com/bcardarella/client_side_validations gem was not ready for rails 4 when this app was developed


// Client side validation for gifts
// These error texts are replaced with language-specific texts in gifts/index page
var csv_gifts_description_required = 'Description is required.' ;
var csv_gifts_price_invalid = 'Price is invalid. Only numbers, max 2 decimals, thousands separator not allowed.' ;
function gifts_client_validations() {
    // check required description
    var gift_description = document.getElementById('gift_description') ;
    if (!gift_description.value || String.trim(gift_description.value) == '') {
        alert(csv_gifts_description_required) ;
        return false ;
    }
    // check optional price. Allow decimal comma/point, max 2 decimals. Thousands separators not allowed
    var gift_price_id = document.getElementById('gift_price') ;
    var gift_price = String.trim(gift_price_id.value) ;
    var gift_price_valid = true ;
    if (gift_price != '') {
      r = new RegExp('^[0-9]*(\.|,)[0-9]{1,2}$') ;
      if (!r.test(gift_price) || (gift_price == '.') || (gift_price == ',')) {
        alert(csv_gifts_price_invalid);
        return false ;
      }
    }
    // gift is ok. ready for submit
    return true ;
} // gifts_client_validations


// update hidden new message buffer page header once every minute
// + update new message count in page header
// + insert new comments in page
function update_new_messages_count()
{
  var new_messages_count_div = document.getElementById("new_messages_count_div") ;
  if (!new_messages_count_div) return ; // table not found
  if (new_messages_count_div.innerHTML == "") return ;
  var new_messages_count = document.getElementById("new_messages_count") ;
  if (!new_messages_count) return ;
  new_messages_count.innerHTML = new_messages_count_div.innerHTML
}
 // update_new_messages_count
function update_title()
{
  var new_mesaages_count = document.getElementById('new_messages_count');
  var no_new_messages = new_mesaages_count.innerHTML ;
  // alert(no_new_messages) ;
  if (no_new_messages == '')
    var new_title = 'Gofreerev' ;
  else
    var new_title = '(' + no_new_messages + ') Gofreerev' ;
  document.title = new_title ;
} // update_title
function insert_new_comments()
{
  var tbody_new_comments = document.getElementById("new_comments_tbody") ;
  if (!tbody_new_comments) return ; // ignore error silently
  var trs_new_comments = tbody_new_comments.rows ;
  if (trs_new_comments.length == 0) return ; // no new comments
  // insert new comments in gifts/index page
  var tr_new_comment, id_new_comment, id_split_new_comment, giftid_new_comment, commentid_new_comment ;
  var tbody_gift_id, tbody_gift, trs_gift ;
  for (i=0 ; i<trs_new_comments.length ; i++) {
    tr_new_comment = trs_new_comments[i] ;
    id_new_comment = tr_new_comment.id ; // format: comment-gift-218-comment-174
    id_split_new_comment = id_new_comment.split("-") ;
    giftid_new_comment = id_split_new_comment[2] ;
    commentid_new_comment = id_split_new_comment[4] ;
    // alert("giftid = " + giftid + ", commentid = " + commentid) ;
    // todo: find relevant gift-comment table, insert row after commentid pos
    tbody_gift_id = "gift-" + giftid_new_comment + "-comments" ;
    tbody_gift = document.getElementById(tbody_gift_id) ;
    if (!tbody_gift) continue ; // table with gift comments not found - ok - could be a not loaded gift
    trs_gift = tbody_gift.rows ;
    if (trs_gift.length == 0) continue ; // error - empty table with gift comments
    if (trs_gift.length == 1) {
      // simple case. first comment - insert first in table
      tbody_new_comment.removeChild(tr_new_comment) ;
      tbody_gift.insertBefore(tr_new_comment, trs_gift[0]) ;
      continue ;
    }
    // first row could be a "show older comments" limk  - last row is a enter new comment row
    trs_gift.length-- ;
    i = trs_gift.length-2 ;

  } // for
} // insert_new_comments
// update new message count in menu line once every minute
// todo: change from once every 10 minutes (600000) to once every minute (60000)
$(document).ready(
    function(){
        setInterval(function(){
            $('#new_messages_buffer_div').load('/util/new_messages_count');
            // copy new_message_count from new_messages_buffer to new_messages_new and to title
            update_new_messages_count() ;
            update_title();
            insert_new_comments() ;
        }, 60000);
    });

// catch load errors  for api pictures. Gift could have been deleted. url could have been changed
// gift ids with invalid picture urls are collected in a global javascript array and submitted to server in 2 seconds
// on error gift.api_picture_url_on_error_at is setted and a new picture url is looked up if possible
// JS array with gift ids
var missing_api_picture_urls = [] ;
// function used in onload for img tags
function check_api_picture_url (giftid, img)
{
  if ((img.width <= 1) && (img.height <= 1)) {
      // image not found - url expired or api picture deleted
      // alert('changed picture url: gift_id = ' + giftid + ', img = ' + img + ', width = ' + img.width + ', height = ' + img.height) ;
      missing_api_picture_urls.push(giftid) ;
  }
  else {
      // image found. rescale
      img.width = 200 ;
  }
} // check_api_picture_url
// function to report gift ids with invalid urls. Submitted in end of gifts/index page
function report_missing_api_picture_urls()
{
  if (missing_api_picture_urls.length == 0) return ;
  // Report ids with invalid picture url
  var missing_api_picture_urls_local = missing_api_picture_urls.join() ;
  $.ajax({
            url: "/util/missing_api_picture_urls",
            type: "POST",
            data: { gifts: {
                ids: missing_api_picture_urls_local}}
  });
  missing_api_picture_urls = [] ;
} // report_missing_picture_urls

// auto resize text fields
// found at http://stackoverflow.com/questions/454202/creating-a-textarea-with-auto-resize
var observe;
if (window.attachEvent) {
    observe = function (element, event, handler) {
        element.attachEvent('on'+event, handler);
    };
}
else {
    observe = function (element, event, handler) {
        element.addEventListener(event, handler, false);
    };
}
function autoresize_text_field (text) {
    function resize () {
        text.style.height = 'auto';
        text.style.height = text.scrollHeight+'px';
    }
    /* 0-timeout to get the already changed text */
    function delayedResize () {
        window.setTimeout(resize, 0);
    }
    observe(text, 'change',  resize);
    observe(text, 'cut',     delayedResize);
    observe(text, 'paste',   delayedResize);
    observe(text, 'drop',    delayedResize);
    observe(text, 'keydown', delayedResize);

    text.focus();
    text.select();
    resize();
}

// post ajax processing after adding a comment.
// comments/create.js.rb inserts new comment last i comments table
// swap the two last rows after ajax processing
function post_ajax_add_new_comment_handler(giftid)
{
    var id = '#gift-' + giftid + '-new-comment-form' ;
    $(document).ready(function(){
        $(id)
            .bind("ajax:success", function(evt, data, status, xhr){
                // swap the two last rows in comments table for gift
                var tbodyname = "gift-" + giftid + "-comments" ;
                var tbody = document.getElementById(tbodyname) ;
                var lasttr = tbody.lastChild ;
                var prevtr = lasttr.previousElementSibling ;
                tbody.removeChild(lasttr) ;
                tbody.insertBefore(lasttr, prevtr) ;
                // empty comment field
                var commentname = 'gift-' + giftid + '-new-comment-textarea'  ;
                var comment = document.getElementById(commentname) ;
                comment.value = "" ;
                comment.focus() ;

            });

    });
} // post_ajax_add_new_comment_handler


// post ajax processing after inserting older comments for a gift.
// comments/index.js.rb inserts older comments last i comments table
// new lines are surrounded by "gift-<giftid>-older-comments-block-start-<commentid>" and "gift-<giftid>-older-comments-block-end-<commentid>".
// move lines up before "show-older-comments" link and delete link
function post_ajax_add_older_comments_handler(giftid, commentid)
{
    // var id = '#gift-' + giftid + '-new-comment-form' ;
    var link_id = 'gift-' + giftid + '-show-older-comments-link-' + commentid ;
    $(document).ready(function(){
        $('#' + link_id)
            .bind("ajax:success", function(evt, data, status, xhr){
                // find tr for old link, first added row and last added row
                var first_row_id = "gift-" + giftid + "-older-comments-block-start-" + commentid ;
                var last_row_id = "gift-" + giftid + "-older-comments-block-end-" + commentid ;
                // find link
                var link = document.getElementById(link_id) ;
                if (!link) return ; // link not found
                // find tr for link
                link_tr = link ;
                while (link_tr.tagName != 'TR') link_tr = link_tr.parentNode ;
                // find first and last added table row
                first_row = document.getElementById(first_row_id) ;
                last_row = document.getElementById(last_row_id) ;
                if (!first_row || !last_row) return ;
                // copy table rows to JS array
                var trs = [] ;
                var tr = first_row.nextElementSibling ;
                while (tr.id != last_row_id) {
                  if (tr.tagName == 'TR') trs.push(tr) ;
                  tr = tr.nextElementSibling ;
                } // while
                // delete table rows from html table
                tr = first_row ;
                var next_tr = tr.nextElementSibling ;
                do {
                  tr.parentNode.removeChild(tr) ;
                  tr = next_tr ;
                  next_tr = tr.nextElementSibling ;
                } while (tr.id != last_row_id) ;
                // insert table rows before old show-older-comments link
                var tbody = link_tr.parentNode ;
                while (trs.length > 0) {
                    tr = trs.shift() ;
                    tbody.insertBefore(tr, link_tr) ;
                }
                // delete link  (and this event handler)
                link_tr.parentNode.removeChild(link_tr) ;
            }); // bind ajax:success
    }); // $(document).ready(function(){
} // add_post_ajax_new_comment_handler

