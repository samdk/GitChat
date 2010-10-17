/* Message */


// Create a message
function Message(author, time, text, issue, commit)
{
  this.author = author;
  this.time = time;
  this.text = text;
  this.issue = issue;
  this.commit = commit;
  
  return this;
}
