FORMAT: 1A
HOST: http://fcore:8080
# Forum Core API

This is a core API for forum like data structures.

Structure:

* Communities
    * Users
        * Private Messages (later)
    * Forums
        * Threads
            * Messages

## The Properties object

Every object has a properties object `p` where up to 64 keys can be stored.  
This object can contain keys with values being String, Number, Boolean, Null and Array.  
An Array inside a property object can be to 64 items long and be String, Number, Boolean and Null.

### Updating the Properties object

When updating a properties object all keys that are supplied will be overwritten.  
Keys that are not supplied won't be touched.  
Keys that need to be deleted must be set to `null`.

## Maximum request size

The maximum request size is 60000 bytes. Responses of course can be bigger.

# Group Community

A community is the root object for all users and forums.

* Every user must belongs to a community.
* Every forum belongs to exactly one community.

Parameters:

* `tpid`(required, String) Third-pary-id (e.g. customer id) - this is required on insert and cannot be changed later.
* `p` (required, Object) Properties with up to 64 keys. (see "The Properties Object")

## New [/c]

Users belong to a community. Create a community before you create any other object.

### Create a new community [POST]

+ Request (application/json)

        {
            "tpid": "123554",
            "p": {
                "name": "BMW Fans"
            }
        }

+ Response 200 (application/json)

        {
            "id": "123554_hxfu56qs",
            "v": "hxfu56qs",
            "p": {
                "name": "BMW Fans"
            }
        }

## Existing [/c/{cid}]

+ Parameters
    + cid (required, string, `123456_hxfu1234`) ... The id of the community.
    
### Retrieve a community [GET]

+ Response 200 (application/json)

        {
            "id": "123554_hxfu56qs",
            "v": "hxfu7578",
            "p": {
                "name": "BMW Fans"
            }
        }

### Update a community [POST]
+ Request (application/json)

        {
            "p": { 
                "name": "Toyota Fans"
            },
            "v": "hxfu56qs"
        }

+ Response 200 (application/json)

        {
            "id": "123554_hxfu56qs",
            "v": "hyh93am4",
            "p": {
                "name": "Toyota Fans"
            }
        }


### Delete a community [DELETE]

+ Response 200 (application/json)

        {
            "id": "123554_hxfu56qs",
            "v": "hyh93am4",
            "p": {
                "name": "Toyota Fans"
            }
        }
        
        
## Query by tpid [/c/query/tpid/{tpid}]  

+ Parameters
    + tpid (required, string, `123456`) ... The third party id (e.g. customer id).

    

### Retrieve all communities of a single `tpid` [GET]

+ Response 200 (application/json)

        [
            {
                "id": "123554_hxfu56qs",
                "v": "hyh93am4",
                "p": {
                    "name": "Toyota Fans"
                }
            }
            ...
        ]

# Group Users

Users belong to a community.

Parameters:

* `id` (String) The user id (name). Must be [a-zA-Z0-9-_] and 3-24 chars long. If no id is supplied a 10 character long id will be generated.
* `extid` *optional* (String) External id (e.g. an email address). A string with 1-256 chars, unique within the community. Can be used to lookup a user by external id.
* `p`: Properties (see "The Properties Object")

Note: The id will be saved as all **lowercase**. If you need to store the original name your might want so save it to the properties object.

## New [/c/{cid}/users]

+ Parameters
    + cid (required, string, `123456_hxfu1234`) ... The id of the community.

### Create a new user [POST]
+ Request (application/json)

        {
            "id": "JohnDoe",
            "p": {
                "sn": "John",
                "ln": "Doe",
                "origName": "JohnDoe",
                "bd": "19810921",
                "pw": "Bcrypt-pwxlskdjsaldkfhj..."
            }
        }
        
+ Response 200 (application/json)

        {
            "id": "johndoe",
            "p": {
                "sn": "John",
                "ln": "Doe",
                "origName": "JohnDoe",
                "bd": "19810921",
                "pw": "Bcrypt-pwxlskdjsaldkfhj..."
            },
            "c": "hxhcj1zt",
            "v": "hxhcj1zt",
        }
      
## Existing [/c/{cid}/users/{userid}]

+ Parameters
    + cid (required, string, `123456_hxfu1234`) ... The id of the community.
    + userid (required, string, `JohnDoe`) ... The user id. **Will be converted to lowercase**

### Retrieve a user [GET]

+ Response 200 (application/json)

        {
            "id": "johndoe",
            "p": {
                "sn": "John",
                "ln": "Doe",
                "origName": "JohnDoe",
                "bd": "19810921",
                "pw": "Bcrypt-pwxlskdjsaldkfhj..."
            },
            "c": "hxhcj1zt",
            "v": "hxhcj1zt",
        }
        
### Update a user [POST]
+ Request (application/json)

        {
            "v": "hxfu56qs",
            "p": {
                "sn": "John",
                "ln": "Doe",
                "origName": "JohnDoe",
                "bd": "19810921",
                "pw": "Bcrypt-ABCDEFGHIJK..."
            },
        }

+ Response 200 (application/json)

        {
            "v": "hyfu1234",
            "p": {
                "sn": "John",
                "ln": "Doe",
                "origName": "JohnDoe",
                "bd": "19810921",
                "pw": "Bcrypt-ABCDEFGHIJK..."
            }
        }

### Delete a user [DELETE]
        
+ Response 200 (application/json)

        {
            "v": "hyfu1234",
            "p": {
                "sn": "John",
                "ln": "Doe",
                "origName": "JohnDoe",
                "bd": "19810921",
                "pw": "Bcrypt-ABCDEFGHIJK..."
            }
        }
        
## Query [/c/{cid}/users?type={type}&esk={esk}]  

+ Parameters
    + cid (required, string, `123456_hxfu1234`) ... The id of the community.
    + type (optional, string, `id`) ... Either `id`, `p` or `all` to return just the id, properties or all. Default: `id`
    + esk (optional, string, `someusername`) ... Exclusive Start Key

### Retrieve the users of a community [GET]

Returns the users of a community.
Maximum users returned is 100.
User the `esk` URL parameter to retrieve the next users.


+ Response 200 (application/json)

        [
            {
                "id": "hyh348ab",
                "cid": "123554_hxfu56qs",
                "n": "My brand new Forum",
                "p": {
                    "desc": "The changed decription of this forum"
                },
                "v": "hyh3bghb"
            }
            ...
        ]
        
    
## Query [/c/{cid}/users/:userid/query?esk=:esk]  

+ Parameters
    + cid (required, string, `123456_hxfu1234`) ... The id of the community.
    + userid (required, string, `JohnDoe`) ... The user id. **Will be converted to lowercase**
    + esk (optional, string, `Mhx123abc`) ... Exclusive Start Key (a message id `id`)    

### Retrieve all messages by a user [GET]

Returns all messages posted by a user in descending order (newest first).  
Maximum messages returned is 25.  
Use the `esk` URL parameter to retrieve the next messages.

+ Response 200 (application/json)

        [
            {
                "fid": "Fhxvghdy4",
                "tid": "Thxvpa5dz",
                "id": "Mhxvpa5yk"
            },
            {
                "fid": "Fhxvghdy4",
                "tid": "Thxvpf77q",
                "id": "Mhxvpf7r9"
            },
            {
                "fid": "Fhxvghdy4",
                "tid": "Thxvpf9y6",
                "id": "Mhxvpfadw"
            }
        ]

   
# Group Forums

* A forum contains threads which are ordered by date.
* Threads contain one or more messages ordered by date.
* Each belongs to exactly one community (`cid`)
* Users of that community can post messages.

## New [/f]

### Create a new forum [POST]
+ Request (application/json)

        {
            "cid": "123554_hxfu56qs",
            "p": {
                "name": "My Forum",
                "desc": "The decription of this forum"
            }
        }

+ Response 200 (application/json)

        {
            "id": "Fhyh348ab",
            "cid": "123554_hxfu56qs",
            "p": {
                "name": "My Forum",
                "desc": "The decription of this forum"
            },
            "tm": 0 // total messages
            "tt": 0 // total threads
            "v": "hyh348ab"
        }

## Existing [/f/{id}]

+ Parameters
    + id (required, string, `Fhyh348ab`) ... The id of the forum.
  
### Retrieve a forum [GET]

+ Response 200 (application/json)

        {
            "id": "Fhyh348ab",
            "cid": "123554_hxfu56qs",
            "p": {
                "name": "My Forum",
                "desc": "The decription of this forum"
            },
            "tm": 0, // total messages
            "tt": 0, // total threads
            "v": "hyh348ab"
        }

        
### Update a forum [POST]
+ Request (application/json)

        {
            "p": {
                "name": "My changed Forum name",
                "desc": "The changed decription of this forum"
            },
            "v": "hyh3baab"
        }

+ Response 200 (application/json)

        {
            "id": "Fhyh348ab",
            "cid": "123554_hxfu56qs",
            "p": {
                "name": "My changed Forum name",
                "desc": "The changed decription of this forum"
            },
            "tm": 0, // total messages
            "tt": 0, // total threads
            "v": "hyh3bghb"
        }
        

### Delete a forum [DELETE]

+ Response 200 (application/json)

        {
            "id": "Fhyh348ab",
            "cid": "123554_hxfu56qs",
            "p": {
                "name": "My Forum",
                "desc": "The decription of this forum"
            },
            "tm": 0, // total messages
            "tt": 0, // total threads
            "v": "hyh348ab"
        }
        

## Query by Third-Party-Id [/f/query/tpid/{tpid}]  

+ Parameters
    + tpid (required, string, `123456`) ... The third party id (e.g. customer id).

### Retrieve all forums of a single `tpid` [GET]

+ Response 200 (application/json)

        [
            {
                "id": "Fhyh348ab",
                "cid": "123554_hxfu56qs",
                 "p": {
                    "name": "My changed Forum name",
                    "desc": "The changed decription of this forum"
                },
                "tm": 0, // total messages
                "tt": 0, // total threads
                "v": "hyh3bghb"
            }
            ...
        ]

## Query by Community Id [/f/query/cid/{cid}]  

+ Parameters
    + cid (required, string, `123554_hxfu56qs`) ... The id of the community.

### Retrieve all forums of a single `cid` [GET]

+ Response 200 (application/json)

        [
            {
                "id": "Fhyh348ab",
                "cid": "123554_hxfu56qs",
                 "p": {
                    "name": "My changed Forum name",
                    "desc": "The changed decription of this forum"
                },
                "tm": 0, // total messages
                "tt": 0, // total threads
                "v": "hyh3bghb"
            }
            ...
        ]
        
# Group Threads

* A thread is the container for messages.
* A thread must be created before creating a message.
* A thread can be deleted (including all messages in it).
* A thread can contain 0 messages. It is up to the application to handle this.
* A thread will have an author (`a`) which cannot be changed and a last author (`la`) which is the author of the latest message.

## New [/f/{fid}/threads]

+ Parameters
    + fid (required, string, `Fhxh3h311`) ... Forum id

### Create a new thread [POST]

+ Request (application/json)

        {
            "a": "JohnDoe",
            "p": {
                "someKey": "foo"
            }
        }

+ Response 200 (application/json)

        {
            "id": "Thysfnvp4",
            "p": {
                "someKey": "foo"
            },
            "a": "JohnDoe",
            "la": "JohnDoe",
            "v":"hysfnvp4",
            "tm":0
        }

## Existing [/f/:fid/threads/:tid]

+ Parameters
    + fid (required, string, `Fhxh3h311`) ... Forum id
    + tid (required, string, `Thyh344ab`) ... The thread id.

    
### Get a thread [GET]

+ Response 200 (application/json)

        {
            "id": "Thxocgl8a",
            "a": "JohnDoe",
            "la": "JohnDoe", // last author
            "v": "hxocgl8a",
            "tm" :1 // total messages in thread
        }

### Update a thread [POST]

When a thread is updated:

* The version `v` of the forum will be touched.

Returns:

The updated thread.

+ Request (application/json)

        {
            "v": "hxocgm1h",
            "p": {
                "someKey": "foo",
                "someNewKey": "bla"
            }
        }


+ Response 200 (application/json)

        {
            "id": "Thxocgl8a",
            "a": "JohnDoe",
            "la": "JohnDoe", // last author
            "v": "hxocgm1h",
            "tm" :1 // total messages in thread,
            "p": {
                "someKey": "foo",
                "someNewKey": "bla"
            }
        }


### Delete a thread [DELETE]

When a thread is deleted:

* The thread is deleted instantly
* The forum counters `tm` and `tt` are updated.
* The messages in the thread will be queued for deletion.

Returns:

The updated forum.

+ Response 200 (application/json)

        {
            "cid": "123554_hz2oczwq",
            "tt": 43,
            "id": "Fhz2oe0o4",
            "tm": 610,
            "v": "hz2opc0n",
            "p": {}
        }
        
        
## Query by Forum Id [/f/{fid}/query?esk=:esk&forward=:forward&bylm=:bylm]

+ Parameters
    + fid (required, string, `Fhxh3h311`) ... Forum id
    + esk (optional, string, `Mhx123abc`) ... Exclusive Start Key (a thread id `id` or `lm` if `bylm` is true)   
    + forward (optional, string, `true`) ... `true` for newest first or `false` for oldest first. 
    + bylm (optional, string, `true`) ... `true` to sort by lastMsgDate (`lm`)

### Retrieve all threads of a single `fid` [GET]

Returns all threads of a forum in descending order (newest first).  
Maximum threads returned is 50.  
Use the supplied `lek` item in the last repsonse item with the `esk` URL parameter for paging.

+ Response 200 (application/json)

        [
            {
                "id": "Tiadvf2mc",
                "lm": "Miadvy3r0",
                "la": "smrchy",
                "p": {},
                "a": "smRChy",
                "tm": 1,
                "v": "iadvy3r1"
            },
            ...
            {
                "id": "Tiadvetgo",
                "lm": "Miadvxudn",
                "la": "smrchy",
                "p": {},
                "a": "smRChy",
                "tm": 2,
                "v": "iadvxudo",
                "lek": "Tiadvetgo"
            }
        ]
        
        
# Group Messages

* A message belongs to exactly one thread. As the thread id (`tid`) must be supplied the thread must exist before saving a message.
* A message can be deleted. If it's the last message in a thread the thread will remain. It is up to the application to update or delete the thread.
* The author `a` must be an existing user (in lowercase).
* When a new message is stored the threads lastAuthor (`la`) field and totalMessages (`tm`) field will be updated.

## New [/f/{fid}/threads/{tid}/messsages]

+ Parameters
    + fid (required, string, `Fhxh3h311`) ... Forum id
    + tid (required, string, `Thyh344ab`) ... The thread id.


### Create a new message [POST]
+ Request (application/json)

        {
            "a": "JohnDoe",
            "p": {
                "b": "Message body"
            }
        }

+ Response 200 (application/json)

        {
            "thread": {
                "id": "Thxocgl8a",
                "a": "JohnDoe",
                "la": "JohnDoe", // last author
                "lm": "Mhxocgll2", // last message id
                "v": "hxocgl8a",
                "tm" :1 // total messages in thread
                "p": {}
            },
            "message": {
                "id": "Mhxocgll2",
                "a": "JohnDoe",
                "v": "hxocgll2"
                "p": {
                  "b": "Message body"
                }
            }
        }
        
## Existing [/forums/:fid/threads/:tid/messages/:mid]

+ Parameters
    + mid (required, string, `Mhxh383h2`) ... Message id
    + fid (required, string, `Fhxh3h311`) ... Forum id
    + tid (required, string, `Thyh344ab`) ... The thread id.

### Get a message [GET]

Note: The `fid` will not be verified. If the message is found in the cache a valid `mid` will return the message.  
If not in cache at least `mid` and `tid` must match.  
You should always have `mid`, `tid` and `fid` correct though.

+ Response 200 (application/json)

        {
            "id": "Mhxocgl8a",
            "b": "The msg body...",
            "a": "JohnDoe",
            "la": "Moderator", // last author if not the original author. 
            "v": "hxocgl8a"
        }

### Update a message [POST]

When a user updates / edits a message. This could be any user of the community.  
The user, if not the author, will be stored in the `la` key of the message.

+ Request (application/json)

        {
            "p": {"some":"data"}
            "a": "Moderator",
            "v": "hxocgl8a"
        }
        
+ Response 200 (application/json)

         {
            "id": "Mhxocgl8a",
            "p": {"some":"data"}
            "a": "Moderator",
            "v": "hxocga4a"
        }

### Delete a message [DELETE]

+ Response 200 (application/json)

        {"deleted": true}

## Query by Thread Id [/f/{fid}/threads/{tid}/query?esk=:esk&forward=:forward&limit=:limit]

+ Parameters
    + fid (required, string, `Fhxh3h311`) ... Forum id
    + tid (required, string, `Thyh344ab`) ... The thread id.
    + esk (optional, string, `Mhx123abc`) ... Exclusive Start Key (a message id `id`)   
    + forward (optional, string, `true`) ... `true` for oldest first or `false` for newest first Default: false
    + limit (optional, number, `10`) ... The amount of messaged to return. Default: 50 (min: 1, max: 50)

### Retrieve all messages of a single `tid` [GET]

Returns all messages of a thread in descending order (newest first).  
Maximum messages returned is 50.  
Use the `esk` URL parameter for paging.

+ Response 200 (application/json)

        [
            {
                "b":"The msg body...",
                "a":"Jack",
                "id":"Mhxwyvuqn",
                "v":"hxwyvuqn"
            }
            ...
        ]
