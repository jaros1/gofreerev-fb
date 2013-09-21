// freeze user_currency when user enters text for new gift (auto submit when currency changes)
function gifts_index_disabled_user_currency() {
    var currency_id;
    currency_id = document.getElementById('user_currency');
    alert('gifts_index_disabled_user_currency, isDisabled = ' + currency_id.isDisabled);

    currency_id.disabled = true;
    var field_id;
    field_id = document.getElementById('gift_price');
    if (field_id.value != '') {
        currency_id.disabled = true;
        return
    }
    field_id = document.getElementById('gift_description');
    if (field_id.value != '') {
        currency_id.disabled = true;
        return
    }
    field_id = document.getElementById('gift_file');
    if (field_id.value != '') {
        currency_id.disabled = true
    }
} // gifts_index_disabled_user_currency


// functions used in page header. Update user currency and return to current page
function pre_update_currency() {
    // use this function to check for other pending changes in currency page before submit
    // eg a confirm popup or maybe copy not saved information to hidden variables in update_currency_form before submit
    return true; // continue
    return false; // stop
} // update_currency_ok
function update_currency() {
    // check if submit is ok (are there other pending changes in page?)
    if (!pre_update_currency()) return;
    // get selected currency
    var user_currency_new_id;
    var user_currency_new;
    var update_currency_div_id;
    var update_currency_form_id;
    var user_currency_id;
    user_currency_new_id = document.getElementById('user_currency_new');
    user_currency_new = user_currency_new_id.value;
    // copy selected currency to hidden form and submit
    update_currency_div_id = document.getElementById('update_currency_div');
    update_currency_form_id = update_currency_div_id.getElementsByTagName('Form')[0];
    user_currency_id = document.getElementById('user_new_currency');
    user_currency_id.value = user_currency_new;
    update_currency_form_id.submit();
} // update_currency_submit

// Version of pre_update_currency to be used in gifts controller pages
var pending_gift_msg = 'Update currency?';
function gifts_pre_update_currency() {
    // get selected currency
    var user_currency_new_id;
    var user_currency_new;
    var update_currency_div_id;
    var update_currency_form_id;
    var user_currency_id;
    user_currency_new_id = document.getElementById('user_currency_new');
    user_currency_new = user_currency_new_id.value;
    if (user_currency_new == '<%= @user.currency %>') return false;
    // check for pending new gift
    var pending_data = false;
    field_id = document.getElementById('gift_price');
    if (field_id.value != '') pending_data = true;
    field_id = document.getElementById('gift_description');
    if (field_id.value != '') pending_data = true;
    field_id = document.getElementById('gift_file');
    if (field_id.value != '') pending_data = true;
    if (!pending_data) return true; // no pending gift
    // confirm box
    return (confirm(pending_gift_msg));
} // gifts_pre_update_currency()


// Client side validations
// https://github.com/bcardarella/client_side_validations gem was not ready for rails 4 when this app was developed


// Client side validation for gifts
// These error texts are replaced with language-specific texts in gifts/index page
var csv_gifts_description_required = 'Description is required.';
var csv_gifts_price_invalid = 'Price is invalid. Only numbers, max 2 decimals, thousands separator not allowed.';
function gifts_client_validations() {
    // check required description
    var gift_description = document.getElementById('gift_description');
    if (!gift_description.value || String.trim(gift_description.value) == '') {
        alert(csv_gifts_description_required);
        return false;
    }
    // check optional price. Allow decimal comma/point, max 2 decimals. Thousands separators not allowed
    var gift_price_id = document.getElementById('gift_price');
    var gift_price = String.trim(gift_price_id.value);
    var gift_price_valid = true;
    if (gift_price != '') {
        r = new RegExp('^[0-9]*(\.|,)[0-9]{1,2}$');
        if (!r.test(gift_price) || (gift_price == '.') || (gift_price == ',')) {
            alert(csv_gifts_price_invalid);
            return false;
        }
    }
    // gift is ok. ready for submit
    return true;
} // gifts_client_validations


function ajax_flash (id)
{
    $('#' + id).css({'background-color':'green'}).animate({'background-color':'white'}, 2000) ;
} // ajax_flash


// check for new messages once every 15, 60 or 300 seconds
// once every 15 seconds for active users - once every 5 minutes for inactive users
var check_new_messages_interval ; // interval in seconds between each new messages check
var check_new_messages_interval_id ; // interval id for setInterval function
var last_user_ajax_comment_at ; // timestamp (JS Date) for last new comment created by user

function calculate_new_messages_interval()
{
    var difference ;
    // how often should client check for new messages?
    if (!last_user_ajax_comment_at)
        check_new_messages_interval = 300 ;
    else {
        difference = ((new Date).getTime() - last_user_ajax_comment_at.getTime()) / 1000 ;
        if (difference < 120) check_new_messages_interval = 15 ;
        else if (difference > 600) check_new_messages_interval = 300 ;
        else check_new_messages_interval = 60  ;
    }
    return check_new_messages_interval ;
} // calculate_new_messages_interval

function start_check_new_messages()
{
    $(document).ready(
        function () {
            var interval = calculate_new_messages_interval() ;
            check_new_messages_interval_id = setInterval(function () {
                // call util/new_messages_count and insert response in new_messages_buffer_div in page header
                // information about number off unread messages
                // and new comments to be inserted in gifts/index page
                // is post ajax processed in JS functions update_new_messages_count, update_title and insert_new_comments
                var check_new_messages_link = document.getElementById("check-new-messages-link");
                // update newest_gift_id before ajax request. newest_gift_id in gifts/index page. 0 in other pages
                // only newer gifts (>newest_gift_id) are ajax inserted in gifts/index page
                var newest_gift_id = document.getElementById("newest-gift-id");
                var newest_gift_id_new_value ;
                if (newest_gift_id && (newest_gift_id.value != '')) newest_gift_id_new_value = newest_gift_id.value ;
                else newest_gift_id_new_value = '0' ;
                var href = check_new_messages_link.href ;
                href = href.replace(/newest_gift_id=[0-9]+/, 'newest_gift_id=' + newest_gift_id_new_value) ;
                check_new_messages_link.href = href ;
                check_new_messages_link.click();
            }, interval * 1000);
        });
} // start_check_new_messages

function restart_check_new_messages()
{
    var old_check_new_messages_interval = check_new_messages_interval ;
    var new_check_new_messages_interval = calculate_new_messages_interval() ;
    if (check_new_messages_interval_id && (old_check_new_messages_interval == new_check_new_messages_interval)) return ; // no change
    if (check_new_messages_interval_id) clearInterval(check_new_messages_interval_id);
    check_new_messages_interval_id = null ;
    start_check_new_messages() ;
} // restart_check_new_messages
// do it
start_check_new_messages() ;


// 3. functions used in util/new_messages_count ajax call.

// update new message count in page header +  insert new comments in page
function update_new_messages_count() {
    // restart setInterval function if refresh period has changed
    restart_check_new_messages() ;
    var new_messages_count_div = document.getElementById("new_messages_count_div");
    if (!new_messages_count_div) return; // table not found
    if (new_messages_count_div.innerHTML == "") return;
    var new_messages_count = document.getElementById("new_messages_count");
    if (!new_messages_count) return;
    new_messages_count.innerHTML = new_messages_count_div.innerHTML
}
// update_new_messages_count
function update_title() {
    var new_mesaages_count = document.getElementById('new_messages_count');
    var no_new_messages = new_mesaages_count.innerHTML;
    // alert(no_new_messages) ;
    if (no_new_messages == '')
        var new_title = 'Gofreerev';
    else
        var new_title = '(' + no_new_messages + ') Gofreerev';
    document.title = new_title;
} // update_title

function insert_new_comments() {
    if (!document.getElementById("gifts")) return ; // no gifts table - not gifts/index page
    var new_comments_tbody, new_comments_trs, new_comment_tr, new_comment_id, new_comment_id_split, new_comment_gift_id, new_comment_comment_id;
    var old_comments_tbody_id, old_comments_tbody, old_comments1_trs, old_comments1_tr, old_comments1_tr_id;
    var i, j, old_comments2_trs, old_comments2_tr, re, old_length, new_length, old_comments2_tr_id;
    var old_comments2_comment_id, inserted, old_comments2_tr_id_split, new_comments_length ;
    var summary ; // for debug info.
    // todo: this is only relevant if current page is gifts/index page
    new_comments_tbody = document.getElementById("new_comments_tbody");
    if (!new_comments_tbody) {
        // alert('new_comments_tbody was not found');
        return; // ignore error silently
    }
    new_comments_trs = new_comments_tbody.rows;
    if (new_comments_trs.length == 0) return; // no new comments

    // insert new comments in gifts/index page. Loop for each new comment.
    new_comments_length = new_comments_trs.length ;
    summary = 'Summary. ' +  new_comments_length + ' messages received' ;
    for (i=new_comments_length-1; i >= 0 ; i--) {
        // find gift id and comment id. id format format: comment-gift-218-comment-174
        new_comment_tr = new_comments_trs[i];
        new_comment_id = new_comment_tr.id;
        new_comment_id_split = new_comment_id.split("-");
        new_comment_gift_id = new_comment_id_split[2];
        new_comment_comment_id = parseInt(new_comment_id_split[4]);
        summary = summary + '. ' + i + ', id = ' + new_comment_id ;
        summary = summary + '. ' + i + ', split[4] = ' + new_comment_id_split[4] ;
        // alert('i = ' + i + ', gift id = ' + new_comment_gift_id + ', comment id = ' + new_comment_comment_id);
        // find table in gifts/index page with comments for gift
        old_comments_tbody_id = "gift-" + new_comment_gift_id + "-comments";
        old_comments_tbody = document.getElementById(old_comments_tbody_id);
        if (!old_comments_tbody) {
          // table with gift comments not found - ok - could be a not loaded gift
          summary = summary + '. ' + i + ': comment table for gift id ' + new_comment_gift_id + ' was not found.' ;
          continue;
        }
        old_comments1_trs = old_comments_tbody.rows;
        if (old_comments1_trs.length == 0) {
          // error - empty table with gift comments
            summary = summary + '. ' + i + ': comment table for gift id ' + new_comment_gift_id + ' is empty.' ;
          continue;

        }
        if (old_comments1_trs.length == 1) {
            // simple case. first comment - insert first in comment table for gift
            new_comment_tr.parentNode.removeChild(new_comment_tr);
            old_comments_tbody.insertBefore(new_comment_tr, old_comments1_trs[0]);
            ajax_flash(new_comment_tr.id) ;
            summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (a) for gift id ' + new_comment_gift_id  ;
            continue;
        }
        // find rows with id format "comment-gift-<gift_id>-comment-%"
        old_comments2_trs = [];
        re = new RegExp("^comment-gift-" + new_comment_gift_id + "-comment-");
        old_length = old_comments1_trs.length;
        for (j = 1; j < old_comments1_trs.length; j++) {
            old_comments1_tr = old_comments1_trs[j];
            old_comments1_tr_id = old_comments1_tr.id;
            if (old_comments1_tr_id.match(re)) old_comments2_trs.push(old_comments1_tr);
        } // end old comments loop
        new_length = old_comments2_trs.length;
        // alert('old length = ' + old_length + ', new length = ' + new_length);
        if (new_length == 0) return; // error - no comments with format "comment-gift-<giftid>-comment-%" was found - ignore error silently
        // insert new comment in comment table (sorted by ascending comment id)
        inserted = false;
        for (j = new_length-1; ((!inserted) && (j >= 0)); j--) {
            // find comment id for current row
            old_comments2_tr = old_comments2_trs[j];
            old_comments2_tr_id = old_comments2_tr.id;
            old_comments2_tr_id_split = old_comments2_tr_id.split('-') ;
            old_comments2_comment_id = parseInt(old_comments2_tr_id_split[4]);
            // alert('j = ' + j + ', new comment id = ' + new_comment_comment_id + ', old id = ' + old_comments2_tr_id + ', old comment id = ' + old_comments2_comment_id);
            if (new_comment_comment_id > old_comments2_comment_id) {
              // insert after current row
              new_comment_tr.parentNode.removeChild(new_comment_tr) ;
              old_comments2_tr.parentNode.insertBefore(new_comment_tr, old_comments2_tr.nextSibling);
              ajax_flash(new_comment_tr.id) ;
              inserted = true ;
              summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (b) for gift id ' + new_comment_gift_id  ;
              continue;
            }
            if (new_comment_comment_id == old_comments2_comment_id) {
              // new comment already in old comments table
              // alert('comment ' + new_comment_comment_id + ' is already in page');
              inserted = true;
              summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (c) for gift id ' + new_comment_gift_id  ;
              continue;
            }
            // insert before current row - continue loop
        } // end old comments loop
        if (!inserted) {
            // insert before first row
            // alert('insert new comment ' + new_comment_id + ' first in old comments table');
            old_comments2_tr = old_comments2_trs[0];
            // alert('old_comments2_tr = ' + old_comments2_tr) ;
            new_comment_tr.parentNode.removeChild(new_comment_tr) ;
            old_comments2_tr.parentNode.insertBefore(new_comment_tr, old_comments2_tr);
            ajax_flash(new_comment_tr.id) ;
            summary = summary + '. ' + i + ': comment ' + new_comment_comment_id + ' inserted (d) for gift id ' + new_comment_gift_id  ;
        } // if
    } // end new comments loop
    // alert(summary) ;
} // insert_new_comments
// update new message count in menu line once every minute


function insert_new_gifts ()
{
    // ajax response from new_messages_count
    // check/update newest_gift_id
    var new_newest_gift_id = document.getElementById("new-newest-gift-id") ;
    if (!new_newest_gift_id) return ; // ok - not gifts/index page or not new gifts
    if  (new_newest_gift_id.value == "") return // error - new_messages_count should return id for newest gift id
    var newest_gift_id = document.getElementById("newest-gift-id") ;
    if (!newest_gift_id) return // error - hidden field was not found i gifts/index page - ignore error silently
    newest_gift_id.value = new_newest_gift_id.value ;
    // check if new_messages_count response has a table with new gifts
    var new_gifts_tbody = document.getElementById("new_gifts_tbody") ;
    if (!new_gifts_tbody) return ; // ok - not gifts/index page or no new gifts to error tbody with new gifts was not found
    // old page: find first gift row in gifts table. id format gift-220-row-1. new gifts from ajax response are to be inserted before this row
    var old_gifts_table = document.getElementById("gifts") ;
    if (!old_gifts_table) return ; // not gifts/index page - ok
    var old_gifts_trs = old_gifts_table.rows ;
    // alert(old_gifts_trs.length + ' gifts lines in old page') ;
    var old_gifts_index ;
    var re = new RegExp('^gift-[0-9]+-row-[0-9]$') ;
    for (var i=0 ; (!old_gifts_index && (i<old_gifts_trs.length)) ; i++) {
        if (old_gifts_trs[i].id.match(re)) old_gifts_index = i ;
    } // for
    // alert('old_gifts_index = ' + old_gifts_index) ;
    if (!old_gifts_index) return ; // error - id with format format gift-220-row-1 was not found - ignore error silently
    var first_old_gift_tr = old_gifts_trs[old_gifts_index] ;
    var old_gifts_tbody = first_old_gift_tr.parentNode ;
    // new gifts from ajax response are to be inserted before first_old_gift_tr
    var new_gifts_trs = new_gifts_tbody.rows ;
    var new_gifts_tr ;
    for (i=new_gifts_trs.length-1 ; i>= 0 ; i--) {
        new_gifts_tr = new_gifts_trs[i] ;
        if (new_gifts_tr.id.match(re)) {
            // insert before "first_old_gift_tr" and move "first_old_gift_tr" to new inserted row
            new_gifts_tr.parentNode.removeChild(new_gifts_tr) ;
            old_gifts_tbody.insertBefore(new_gifts_tr, first_old_gift_tr) ;
            first_old_gift_tr = new_gifts_tr ;
            ajax_flash(first_old_gift_tr.id) ;
        } // if
    } // for
    // that's it
} //  insert_new_gifts


// catch load errors  for api pictures. Gift could have been deleted. url could have been changed
// gift ids with invalid picture urls are collected in a global javascript array and submitted to server in 2 seconds
// on error gift.api_picture_url_on_error_at is setted and a new picture url is looked up if possible
// JS array with gift ids
var missing_api_picture_urls = [];
// function used in onload for img tags
function check_api_picture_url(giftid, img) {
    if ((img.width <= 1) && (img.height <= 1)) {
        // image not found - url expired or api picture deleted
        // alert('changed picture url: gift_id = ' + giftid + ', img = ' + img + ', width = ' + img.width + ', height = ' + img.height) ;
        missing_api_picture_urls.push(giftid);
    }
    else {
        // image found. rescale
        img.width = 200;
    }
} // check_api_picture_url
// function to report gift ids with invalid urls. Submitted in end of gifts/index page
function report_missing_api_picture_urls() {
    if (missing_api_picture_urls.length == 0) return;
    // Report ids with invalid picture url
    var missing_api_picture_urls_local = missing_api_picture_urls.join();
    $.ajax({
        url: "/util/missing_api_picture_urls",
        type: "POST",
        data: { gifts: {
            ids: missing_api_picture_urls_local}}
    });
    missing_api_picture_urls = [];
} // report_missing_picture_urls

// auto resize text fields
// found at http://stackoverflow.com/questions/454202/creating-a-textarea-with-auto-resize
var observe;
if (window.attachEvent) {
    observe = function (element, event, handler) {
        element.attachEvent('on' + event, handler);
    };
}
else {
    observe = function (element, event, handler) {
        element.addEventListener(event, handler, false);
    };
}
function autoresize_text_field(text) {
    function resize() {
        text.style.height = 'auto';
        text.style.height = text.scrollHeight + 'px';
    }

    /* 0-timeout to get the already changed text */
    function delayedResize() {
        window.setTimeout(resize, 0);
    }

    observe(text, 'change', resize);
    observe(text, 'cut', delayedResize);
    observe(text, 'paste', delayedResize);
    observe(text, 'drop', delayedResize);
    observe(text, 'keydown', delayedResize);

    text.focus();
    text.select();
    resize();
}

// post ajax processing after adding a comment.
// comments/create.js.rb inserts new comment last i comments table
// clear comment text area and reset frequency for new message check
function post_ajax_add_new_comment_handler(giftid) {
    var id = '#gift-' + giftid + '-new-comment-form';
    $(document).ready(function () {
        $(id)
            .bind("ajax:success", function (evt, data, status, xhr) {
                var commentname = 'gift-' + giftid + '-new-comment-textarea';
                var comment = document.getElementById(commentname);
                comment.value = "";
                // comment.focus();
                // save timestamp for last new ajax comment
                last_user_ajax_comment_at = new Date() ;
                restart_check_new_messages() ;
            });

    });
} // post_ajax_add_new_comment_handler


// post ajax processing after inserting older comments for a gift.
// comments/index.js.rb inserts older comments last i comments table
// new lines are surrounded by "gift-<giftid>-older-comments-block-start-<commentid>" and "gift-<giftid>-older-comments-block-end-<commentid>".
// move lines up before "show-older-comments" link and delete link
function post_ajax_add_older_comments_handler(giftid, commentid) {
    // var id = '#gift-' + giftid + '-new-comment-form' ;
    var link_id = 'gift-' + giftid + '-show-older-comments-link-' + commentid;
    $(document).ready(function () {
        $('#' + link_id)
            .bind("ajax:success", function (evt, data, status, xhr) {
                // find tr for old link, first added row and last added row
                var first_row_id = "gift-" + giftid + "-older-comments-block-start-" + commentid;
                var last_row_id = "gift-" + giftid + "-older-comments-block-end-" + commentid;
                // find link
                var link = document.getElementById(link_id);
                if (!link) return; // link not found
                // find tr for link
                var link_tr = link;
                while (link_tr.tagName != 'TR') link_tr = link_tr.parentNode;
                // find first and last added table row
                var first_row = document.getElementById(first_row_id);
                var last_row = document.getElementById(last_row_id);
                if (!first_row || !last_row) return;
                // copy table rows to JS array
                var trs = [];
                var tr = first_row.nextElementSibling;
                while (tr.id != last_row_id) {
                    if (tr.tagName == 'TR') trs.push(tr);
                    tr = tr.nextElementSibling;
                } // while
                // delete table rows from html table
                tr = first_row;
                var next_tr = tr.nextElementSibling;
                do {
                    tr.parentNode.removeChild(tr);
                    tr = next_tr;
                    next_tr = tr.nextElementSibling;
                } while (tr.id != last_row_id) ;
                // insert table rows before old show-older-comments link

                var tbody = link_tr.parentNode;
                while (trs.length > 0) {
                    tr = trs.shift();
                    tbody.insertBefore(tr, link_tr);
                }
                // delete link  (and this event handler)
                link_tr.parentNode.removeChild(link_tr);
            }); // bind ajax:success
    }); // $(document).ready(function(){
} // add_post_ajax_new_comment_handler

// show/hide price and currency in new comment table call
function check_uncheck_new_deal_checkbox(checkbox, giftid)
{
    var tr = document.getElementById("gift-" + giftid + "-new-comment-price-tr") ;
    if (checkbox.checked) tr.style.display='block' ;
    else tr.style.display = 'none' ;
    // alert(checkbox);
} // check_uncheck_new_deal_checkbox

