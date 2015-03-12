S3 command provides a command line tool set for interacting with Amazon Simple Storage Service. It is written in perl using the Net::Amazon::S3 module. I wrote it because I wanted clean, simple, reliable and easily maintained command line tool to access S3 and which would work well for managing backup files stored on S3.

Version 0.9 was released on 7/28/2008.

It supports:

creating and deleting buckets (mkbucket, rmbucket)
uploading, downloading and deleting files (get, put, rm)
hierarchical filesystem like view of Amazon S3 key space
short and long file listings (ls, ls -l)
sending only changed files (push)
storage space used (du)
The "push" sub-command is designed to be used in cron jobs and backup scripts. You can run this automatically against a set of local files to ensure that each file gets copied up to S3. It doesn't resend the file if it's already on S3 and hasn't changed. That's obviously very useful if you're mirroring large backup files to S3. If the local file has been changed, it's hard to know whether to overwrite the copy in S3. The changed local file may be the correct most recent copy, in which case it should be stored. But what if the local file has been corrupted? Blithely overwriting the good copy on S3 with the corrupted file would be bad. So instead "push" creates a new version of the file on S3 each time there are changes. You can figure out at a later time whether to delete any copies, but at least the backup script won't discard something by overwriting it.

In some ways S3 command provides similar functionality to the s3cmd.rb script from the s3sync.rb ruby package and the s3cmd python package.

-- Oliver Crow, ocrow@simplexity.net
