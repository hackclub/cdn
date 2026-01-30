# Guide for migrating from one S3-Compatible bucket to another.
1. Install `rclone`
```
curl https://rclone.org/install.sh | sudo bash
```
2. Add the S3 Providers to `rclone`
```
rclone config
```
3. Run migration
> `oldprovider` and `newprovider` are the names you used to add the providers to rclone, `bucketname` is the name of the S3-Compatible bucket.
> Do dry run first:
```
rclone sync oldprovider:bucketname newprovider:bucketname --dry-run
```
> Now for real:
```
rclone sync oldprovider:bucketname newprovider:bucketname
```
4. Done


