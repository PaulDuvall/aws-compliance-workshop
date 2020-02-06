import boto3

ec2 = boto3.client('ec2')

# Retrieves all regions/endpoints that work with EC2
aws_regions = ec2.describe_regions()

# Get a list of regions and then instantiate a new ec2 client for each region in order to get list of AZs for the region
for region in aws_regions['Regions']:
    my_region_name = region['RegionName']
    ec2_region = boto3.client('ec2', region_name=my_region_name)
    my_region = [{'Name': 'region-name', 'Values': [my_region_name]}]
    print ("Current Region is %s" % my_region_name)
    aws_azs = ec2_region.describe_availability_zones(Filters=my_region)
    for az in aws_azs['AvailabilityZones']:
        zone = az['ZoneName']
        print(zone)