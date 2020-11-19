<?php

class DomainHandler
{
    /**
     * @var PDO|null
     */
    private ?PDO $_pdo;
    /**
     * @var Redis
     */
    private Redis $_redis;
    /**
     * @var int
     */
    private int $_batch;
    /**
     * @var int
     */
    private int $_current;
    /**
     * @var array
     */
    private array $_domains;

    /**
     * Counter constructor.
     * @param array $pdoCreds
     * @param int $batch
     */
    function __construct(array $pdoCreds, int $batch = 500)
    {
        $this->_pdo = new PDO($pdoCreds['host'], $pdoCreds['user'], $pdoCreds['password']);
        $this->_batch = $batch;
        $this->_redis = new Redis();
        $this->_redis->connect('localhost', 6379);
        if ($this->_redis->get('current')) {
            $this->_current = $this->_redis->get('current');
        } else {
            $this->_current = 0;
        }

    }

    private function count()
    {
        $res = $this->_pdo->prepare('SELECT COUNT(*) FROM users');
        $res->execute();
        $count = $res->fetchColumn();

        return (int)ceil($count / $this->_batch);
    }

    public function run()
    {
        $count = $this->count();
        for ($i = $this->_current; $i <= $count; $i++) {
            $res = $this->_pdo->prepare('SELECT id, email FROM users order by id limit :curr, :batch');
            $res->bindValue(':curr', $this->_current, PDO::PARAM_INT);
            $res->bindValue(':batch', $this->_batch, PDO::PARAM_INT);
            $res->execute();

            while ($row = $res->fetch(PDO::FETCH_ASSOC)) {
                $domains = $this->getDomains($row['email']);
                foreach ($domains as $domain) {
                    if ($domain) {
                        $this->addDomain($domain);
                    }
                }
            }

            $this->saveBatchData();
            $this->_current += $this->_batch;
            $this->_redis->set('current', $this->_current);
        }

    }

    private function getDomains($email)
    {
        preg_match_all('/@(.*?)(?=,|$)/ui', $email, $currentDomains);

        if (!isset($currentDomains[1])) {
            return [];
        }

        return $currentDomains[1];
    }

    private function addDomain($domain)
    {
        if (!isset($this->_domains[$domain])) {
            $this->_domains[$domain] = 0;
        }
        $this->_domains[$domain]++;
    }

    private function saveBatchData()
    {
        /**
         * Здесь реализуется функионал по сохранению просмотренных данных, либо в файл, либо создать таблицу с данными и обнавлять их после каждого batch
         */
    }
}

$pdoCreds = ['host' => 'mysql:host=localhost;dbname=db', 'user' => 'root', 'password' => 'password'];
$batch = 1000;
$counter = new DomainHandler($pdoCreds, $batch);
$counter->run();
die();
