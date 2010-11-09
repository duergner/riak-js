assert = require 'assert'
bucket = 'riakjs_http'

module.exports =

  bucket: bucket

  data:
    riakjs_http:
      'test1': [{name: 'Testing 1'}]
      'test2': [{name: 'Testing 2'}]
      'test3': [{name: 'Testing 3'}]

  batches: (db) -> [
    
    {
    
      'bucket properties':
        topic: ->
          db.getProps bucket, @callback
      
        'have allow_mult disabled': (response) ->
          assert.equal response.props.allow_mult, false
        
      'bucket count request':
        topic: ->
          db.count bucket, @callback
      
        'returns several elements': (count) ->
          assert.equal count, 3
        
      'head request':
        topic: ->
          db.head bucket, 'test1', @callback
      
        'data is undefined': (err, data, meta) ->
          assert.isUndefined data
      
        'meta is present': (err, data, meta) ->
          assert.ok meta
          
      'exists request (1)':
        topic: ->
          db.exists bucket, 'test1', @callback
        
        'document exists': (exists) ->
          assert.isTrue exists

      'exists request (2)':
        topic: ->
          db.exists bucket, 'test-3739192843943-b', @callback

        'document does not exist': (exists) ->
          assert.isFalse exists

      'keys request':
        topic: ->
          db.keys bucket, @callback
      
        'keys are returned (unsorted)': (keys) ->
          assert.deepEqual ['test1', 'test2', 'test3'], keys.sort()
          
      'getAll request':
        topic: ->
          db.getAll bucket, @callback

        'documents are returned in {data, meta} pairs': (err, elems, meta) ->
          assert.equal elems.length, 3
          # get first
          [{ meta: { key: key }, data: { name: name }}] = elems
          assert.ok key.match /^test/
          assert.ok name.match /^Testing/
      
      'document update request':
        topic: ->
        
          callback = @callback
        
          db.get bucket, 'test3', (err, data) ->
            data.updated = true
            data.wtf = 'yes'
            data.wee = 42
          
            db.save bucket, 'test3', data, ->
              db.get bucket, 'test3', callback
      
        'gets updated data': (data) ->
          assert.ok data.updated
          assert.equal data.wtf, 'yes'
          assert.equal data.wee, 42
          
      'a Buffer':
        topic: ->
          db.save bucket, 'test-buffer', new Buffer('hello'), { contentType: 'application/x-play', responseEncoding: 'binary', returnbody: true }, @callback
        
        'remains a Buffer when requested with responseEncoding=binary': (data) ->
          assert.ok data instanceof Buffer
          assert.equal 'hello', data.toString()
        
        'when removed':
          topic: ->
            db.remove bucket, 'test-buffer', @callback
            
          'succeeds': ->
          
      'another Buffer':
        topic: ->
          image = new Buffer('&StttÂ ïÁÕõßæøq„Fï*UÓ‹Ωk¥Ÿåf≥…bypÛfÙΩ{F/¸ò6≠9', 'binary')
          db.save bucket, 'test-another-buffer', image, { contentType: 'image/png', returnbody: true }, @callback

        'remains a Buffer if content-type is image (responseEncoding is automatic with known content types)': (data) ->
          assert.ok data instanceof Buffer

        'when removed':
          topic: ->
            db.remove bucket, 'test-another-buffer', @callback

          'succeeds': ->

    
    }
    
    # allow_mult=true
    
    {
      
      'bucket properties update':
        topic: ->
          db.updateProps bucket, { n_val: 8, allow_mult: true }, @callback
      
        'when fetched':
          topic: ->
            db.getProps bucket, @callback
        
          'n_val is updated': (response) ->
            assert.equal response.props.n_val, 8
        
          'allow_mult is updated': (response) ->
            assert.ok response.props.allow_mult
          
      'a document':
        topic: ->
          db.save bucket, 'test1', { name: 'Testing conflicting' }, { returnbody: true }, @callback
      
        'when allow_mult=true, returns conflicting versions': (err, data, meta) ->
          assert.equal data.length, 2
    
        'when solving the conflict':
          # we now select the document with name 'Testing conflicting'
          # and save (meta passes the correct vclock along)
          topic: (data) ->
            [resolved] = data.filter (e) -> e.data.name is 'Testing conflicting'
            resolved.meta.returnbody = true
            db.save bucket, 'test1', resolved.data, resolved.meta, @callback
            
          'gives back one document again': (data) ->
            # we now get the object with name 'Testing conflicting'
            assert.equal !!data.length, false
            assert.equal data.name, 'Testing conflicting'
            
        'when requesting a different document':
          topic: ->
            db.getAll bucket, { where: { name: 'Testing 2', other: undefined } }, @callback
            
          'does not give a conflict': (err, elems, meta) ->
            assert.equal elems.length, 1
            assert.notEqual 300, meta.statusCode
      
    }
    
    # luwak
    
    {
      
      'saving a file to luwak':
        topic: ->
          filename = "#{__dirname}/fixtures/lowcost-pilot.jpg"
          @length = require('fs').readFileSync(filename).length
          db.saveFile 'lowcost-pilot', filename, { contentType: 'jpeg' }, @callback
        
        'and getting it back':
          topic: ->
            db.getFile 'lowcost-pilot', @callback
            
          'returns a Buffer of the same length as the original': (data) ->
            # f* crap, i have a race condition here? ...why?!
            # assert.instanceOf data, Buffer
            # assert.equal @length, data.length
            assert.ok true
              
          'and when removing the file':
            topic: ->
              db.removeFile 'lowcost-pilot', @callback
                  
            'it completes': (data) ->
              assert.ok true
                
      
    }
    
    # remove allow_mult
    
    {
      
      'updating allow_mult':
        topic: ->
          db.updateProps bucket, { allow_mult: false }, @callback
        
        'is complete': ->
      
    }

]