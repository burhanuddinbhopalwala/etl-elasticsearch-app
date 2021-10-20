# frozen_string_literal: true

#* http://www.linuxandubuntu.com/home/what-are-zombie-processes-and-how-to-find-kill-zombie-processes
require('logger')
require('byebug')

def main
  logger = Logger.new(STDOUT)
  zombies_ids = `ps -aux | grep "[d]efunct" | awk '{print $2}'`
  if zombies_ids.empty?
    logger.info('NO ZOMBIE PROCESSES FOUND')
    return
  end
  zombies_ids = zombies_ids.chomp!.split("\n")
  unless zombies_ids.empty?
    zombies_ids.each do |zombies_id|
      Process.kill('-SIGKILL', zombies_id.to_i)
      logger.info("TRIED KILLIG ZOMBIE PROCESS WITH ID #{zombies_id}")
    rescue StandardError => e
      logger.info("ERROR KILLING ZOMBIE PROCESS WITH ID #{zombies_id}, DUE TO #{e.message}")
    end
  end
rescue StandardError => e
  logger.error("ZOMBIE SCRIPT ERROR DUE TO #{e.message}")
end

main
