'''
Provide access to random uuid generator
'''

import uuid


__virtualname__ = 'uuid'


def __virtual__():
    return __virtualname__


def rand_uuid():
    '''
    Returns a random uuid.

    CLI Example:

    .. code-block:: bash

        salt '*' uuid.rand_uuid
    '''
    return str(uuid.uuid4())
